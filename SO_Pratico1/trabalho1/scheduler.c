#include "scheduler.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "msg.h"

static const char *SCHED_NAMES[] = { "FIFO", "SJF", "RR", "MLFQ", NULL };
static sched_algo_en sched_algo = SCHED_FIFO;

#define MLFQ_LEVELS    3
#define MLFQ_BOOST_MS  5000   // de quanto em quanto tempo tudo volta ao nível 0

static queue_t mlfq_queues[MLFQ_LEVELS] = {0};
static uint32_t mlfq_last_boost_ms = 0;

int set_sched_algo(const char *name) {
    for (int i = 0; SCHED_NAMES[i] != NULL; i++) {
        if (strcasecmp(SCHED_NAMES[i], name) == 0) {
            sched_algo = (sched_algo_en) i;
            return sched_algo;
        }
    }
    return -1;
}

const char *get_sched_algo_str(void) {
    return SCHED_NAMES[sched_algo];
}

static void finish_burst(uint32_t current_time_ms, queue_t *cq, pcb_t *task) {
    msg_t msg = {
        .pid = task->pid,
        .request = PROCESS_REQUEST_DONE,
        .time_ms = current_time_ms
    };
    if (write(task->sockfd, &msg, sizeof(msg_t)) != sizeof(msg_t)) {
        perror("write");
    }
    enqueue_pcb(cq, task);
}

/**
 * Passa todos os PCBs que acabaram de chegar à ready queue partilhada (rq)
 * para a fila MLFQ correspondente ao seu nível atual (pcb->mlfq_level).
 */
static void mlfq_admit_new_arrivals(queue_t *rq) {
    pcb_t *task;
    while ((task = dequeue_pcb(rq)) != NULL) {
        if (task->mlfq_level < 0 || task->mlfq_level >= MLFQ_LEVELS) {
            task->mlfq_level = 0;
        }
        enqueue_pcb(&mlfq_queues[task->mlfq_level], task);
    }
}

/**
 * Escolhe o próximo processo: a fila de maior prioridade não vazia
 * (nível mais baixo primeiro), por ordem FIFO dentro dessa fila.
 */
static pcb_t *mlfq_pick_next(void) {
    for (int lvl = 0; lvl < MLFQ_LEVELS; lvl++) {
        pcb_t *task = dequeue_pcb(&mlfq_queues[lvl]);
        if (task) return task;
    }
    return NULL;
}

/**
 * Reforço periódico (priority boost): evita starvation, trazendo tudo
 * de volta ao nível 0 de tempos a tempos.
 */
static void mlfq_priority_boost(uint32_t current_time_ms) {
    if (current_time_ms - mlfq_last_boost_ms < MLFQ_BOOST_MS) return;
    mlfq_last_boost_ms = current_time_ms;

    for (int lvl = 1; lvl < MLFQ_LEVELS; lvl++) {
        pcb_t *task;
        while ((task = dequeue_pcb(&mlfq_queues[lvl])) != NULL) {
            task->mlfq_level = 0;
            enqueue_pcb(&mlfq_queues[0], task);
        }
    }
}

int scheduler(uint32_t current_time_ms, queue_t *rq, queue_t *cq, pcb_t **cpu_task) {
    if (sched_algo == SCHED_MLFQ) {
        mlfq_admit_new_arrivals(rq);
        mlfq_priority_boost(current_time_ms);
    }
    if (*cpu_task) {
        (*cpu_task)->ellapsed_time_ms += TICKS_MS;

        if ((*cpu_task)->ellapsed_time_ms >= (*cpu_task)->time_ms) {
            printf("Time [ms]: %d\tPID: %d\tSTOP_RUNNING\n", current_time_ms, (*cpu_task)->pid);
            finish_burst(current_time_ms, cq, *cpu_task);
            *cpu_task = NULL;
        }
        else if (sched_algo == SCHED_RR &&
                 (current_time_ms - (*cpu_task)->slice_start_ms) >= TIME_SLICE_MS) {
            printf("Time [ms]: %d\tPID: %d\tPREEMPTED (time-slice)\n", current_time_ms, (*cpu_task)->pid);
            enqueue_pcb(rq, *cpu_task);
            *cpu_task = NULL;
        }
        else if (sched_algo == SCHED_MLFQ &&
                 (current_time_ms - (*cpu_task)->slice_start_ms) >= TIME_SLICE_MS) {
            if ((*cpu_task)->mlfq_level < MLFQ_LEVELS - 1) {
                (*cpu_task)->mlfq_level++;
            }
            printf("Time [ms]: %d\tPID: %d\tPREEMPTED (time-slice) -> nivel %d\n",
                   current_time_ms, (*cpu_task)->pid, (*cpu_task)->mlfq_level);
            enqueue_pcb(&mlfq_queues[(*cpu_task)->mlfq_level], *cpu_task);
            *cpu_task = NULL;
        }
    }

    if (*cpu_task == NULL) {
        if (sched_algo == SCHED_FIFO || sched_algo == SCHED_RR) {
            *cpu_task = dequeue_pcb(rq);
        } else if (sched_algo == SCHED_SJF) {
            *cpu_task = dequeue_pcb_sjf(rq);
        } else if (sched_algo == SCHED_MLFQ) {
            *cpu_task = mlfq_pick_next();
        } else {
            printf("Scheduling algorithm not implemented yet. \n");
        }
        if (*cpu_task) {
            (*cpu_task)->slice_start_ms = current_time_ms;
            printf("Time [ms]: %d\tPID: %d\tSTAR_RUNNING", current_time_ms, (*cpu_task)->pid);
            if (sched_algo == SCHED_MLFQ) {
                printf("\t(nivel %d)", (*cpu_task)->mlfq_level);
            }
            printf("\n");
            return 1;
        }
    }
    return 0;
}