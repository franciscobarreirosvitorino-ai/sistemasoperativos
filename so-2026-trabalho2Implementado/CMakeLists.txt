cmake_minimum_required(VERSION 3.25)
project(OSSIM C)

set(CMAKE_C_STANDARD 11)

add_compile_options(-Wall -Wextra -Wno-unused-parameter)

add_executable(ossim ossim.c queue.c scheduler.c virtmem.c)

add_executable(application application.c burst_queue.c)

enable_testing()
add_executable(test_vm test_vm.c virtmem.c queue.c)
# Os testes usam assert, incluindo nas compilações Release.
target_compile_options(test_vm PRIVATE -UNDEBUG)
add_test(NAME algoritmos_vm COMMAND test_vm)

# ---------------------------------------------------------------------------
# Alvo "archive": cria build/entrega.zip com todos os ficheiros necessarios
# para compilar e correr o projeto (fontes, cabecalhos, CMakeLists, scripts
# e ficheiros de cenario). E este zip que os alunos devem entregar.
#
#   cmake -S . -B build
#   cmake --build build --target archive     # -> build/entrega.zip
#
# O nome e a pasta do zip sao configuraveis:
#
#   cmake -S . -B build -DOSSIM_ARCHIVE_NAME=outro.zip -DOSSIM_ARCHIVE_DIR=/tmp
# ---------------------------------------------------------------------------

set(OSSIM_ARCHIVE_NAME "entrega.zip" CACHE STRING "Nome do ficheiro criado pelo alvo archive")
set(OSSIM_ARCHIVE_DIR "${CMAKE_BINARY_DIR}" CACHE PATH "Pasta onde o alvo archive cria o zip")

file(GLOB OSSIM_ARCHIVE_ROOT CONFIGURE_DEPENDS RELATIVE "${CMAKE_SOURCE_DIR}"
        "${CMAKE_SOURCE_DIR}/*.c"
        "${CMAKE_SOURCE_DIR}/*.h"
        "${CMAKE_SOURCE_DIR}/*.csv"
        "${CMAKE_SOURCE_DIR}/*.sh"
        "${CMAKE_SOURCE_DIR}/*.py"
        "${CMAKE_SOURCE_DIR}/*.md")

file(GLOB_RECURSE OSSIM_ARCHIVE_SCENARIOS CONFIGURE_DEPENDS RELATIVE "${CMAKE_SOURCE_DIR}"
        "${CMAKE_SOURCE_DIR}/scenarios/*")
file(GLOB_RECURSE OSSIM_ARCHIVE_CENARIOS CONFIGURE_DEPENDS RELATIVE "${CMAKE_SOURCE_DIR}"
        "${CMAKE_SOURCE_DIR}/cenarios/*"
        "${CMAKE_SOURCE_DIR}/resultados/*")

add_custom_target(archive
        COMMAND ${CMAKE_COMMAND} -E make_directory "${OSSIM_ARCHIVE_DIR}"
        COMMAND ${CMAKE_COMMAND} -E tar cf "${OSSIM_ARCHIVE_DIR}/${OSSIM_ARCHIVE_NAME}" --format=zip --
        CMakeLists.txt
        ${OSSIM_ARCHIVE_ROOT}
        ${OSSIM_ARCHIVE_SCENARIOS}
        ${OSSIM_ARCHIVE_CENARIOS}
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMENT "A criar ${OSSIM_ARCHIVE_DIR}/${OSSIM_ARCHIVE_NAME}"
        VERBATIM)
