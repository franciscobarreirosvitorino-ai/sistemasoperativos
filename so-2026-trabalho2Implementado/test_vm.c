#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "virtmem.h"

static array_t fixture(void) {
    array_t a;
    assert(init_eviction_arr(&a, 3) == 0);
    assert(update_eviction_array(&a, 10, 1));
    assert(update_eviction_array(&a, 20, 2));
    assert(update_eviction_array(&a, 30, 3));
    assert(update_eviction_array(&a, 10, 4));
    return a;
}

int main(void) {
    const char *names[] = {"FIFO", "RANDOM", "LRU", "NRU", "CLOCK"};
    for (int k = 0; k < 5; ++k) {
        assert(set_eviction_algo(names[k]) == k);
        assert(evict(NULL) == INVALID_PFN);
        array_t empty;
        assert(init_eviction_arr(&empty, 1) == 0);
        assert(evict(&empty) == INVALID_PFN);
        update_eviction_array(&empty, 42, 1);
        assert(evict(&empty) == 42);
        assert(evict(&empty) == INVALID_PFN);
        free(empty.ids);
    }
    assert(set_eviction_algo("invalid") == -1);
    assert(set_eviction_algo("lru") == LRU);
    array_t a = fixture();
    assert(lru_eviction(&a) == 20);
    free(a.ids);
    a = fixture();
    set_eviction_algo("FIFO");
    assert(evict(&a) == 10);
    free(a.ids);
    a = fixture();
    a.ids[1].use_bit = 0;
    assert(nru_eviction(&a) == 20);
    assert(nru_eviction(&a) == 10);
    free(a.ids);
    a = fixture();
    assert(clock_eviction(&a) == 10); /* volta completa, limpa R */
    update_eviction_array(&a, 20, 5); /* segunda oportunidade */
    assert(clock_eviction(&a) == 30);
    assert(clock_eviction(&a) == 20);
    free(a.ids);
    a = fixture();
    a.last_index = 2;
    remove_from_eviction_array(&a, 10);
    assert(a.last_index == 1 && a.ids[a.last_index].pfn == 30);
    free(a.ids);
    a = fixture();
    srand(7);
    int seen = 0;
    for (int i = 0; i < 3; ++i) {
        int pfn = random_eviction(&a);
        assert(pfn == 10 || pfn == 20 || pfn == 30);
        int bit = 1 << (pfn / 10);
        assert(!(seen & bit));
        seen |= bit;
    }
    assert(seen == 14);
    free(a.ids);
    set_eviction_algo("NRU");
    pcb_t period_pcb = { .pid = 99 };
    swap_hash_t period_swap = {0};
    frame_table_t *period_ft = create_frame_table(5);
    assert(create_page_table(&period_pcb.page_table, 5) == 0);
    for (int vpn = 1; vpn <= 5; ++vpn) {
        pte_t *pte = page_request(&period_pcb, period_ft, &period_swap, vpn);
        assert(pte);
        pte->present = 1;
    }
    assert(period_ft->eviction_order.ids[0].use_bit == 0);
    assert(period_ft->eviction_order.ids[4].use_bit == 1);
    free(period_pcb.page_table.ptes);
    free(period_ft->frames); free(period_ft->free_stack.ids);
    free(period_ft->eviction_order.ids); free(period_ft);
    /* Integração RAM/swap: página máxima válida, retorno e libertação. */
    for (int k = 0; k < 5; ++k) {
        set_eviction_algo(names[k]);
        pcb_t pcb = { .pid = 123 };
        swap_hash_t swap = {0};
        frame_table_t *ft = create_frame_table(1);
        assert(create_page_table(&pcb.page_table, 3) == 0);
        assert(find_page(&pcb.page_table, 0) == NULL);
        assert(find_page(&pcb.page_table, 4) == NULL);
        int refs[] = {3, 1, 3, 2, 3};
        for (int i = 0; i < 5; ++i) {
            pte_t *pte = page_request(&pcb, ft, &swap, refs[i]);
            assert(pte);
            pte->present = 1;
        }
        assert(page_eviction(ft, &swap, 1) == 0);
        assert(free_frames_from_memory(ft, pcb.pid) == 0);
        assert(ft->free_stack.top == 0);
        destroy_swap(&swap);
        free(pcb.page_table.ptes);
        free(ft->frames); free(ft->free_stack.ids);
        free(ft->eviction_order.ids); free(ft);
    }
    puts("Todos os testes VM passaram.");
    return 0;
}
