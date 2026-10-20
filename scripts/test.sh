#!/usr/bin/env bash
# Uso: bash scripts/test.sh [Debug|Release] [headless|all]. Padrão: Release, como a CI oficial.
# headless corresponde ao conjunto Linux da CI oficial. all pode exigir GPU.
operation=test
default_config=Release
source "$(dirname "$0")/container-common.sh"
suite=${2:-headless}
case "$suite" in
  headless)
    targets=(audio_out2_port_tests pad_haptics_tests controller_settings_tests host_input_tests
      ime_dialog_tests lru_cache_tests memory_tracker_tests page_manager_tests
      resource_tracking_tests scalar_provenance_tests resource_materialization_tests
      shader_vertex_metadata_tests archive_file_tests avplayer_file_tests virtual_memory_allocation_tests)
    pattern='^(audio_out2_port|pad_haptics|controller_settings|host_input|ime_dialog|lru_cache|memory_tracker|page_manager|resource_tracking|scalar_provenance|resource_materialization|shader_vertex_metadata|archive_file|avplayer_file|virtual_memory_allocation)$'
    ;;
  all) targets=(kyty_emulator kyty_tests); pattern='.*' ;;
  *) echo 'Suite: headless ou all.' >&2; exit 2 ;;
esac
configure
cmake --build "$build_dir" --parallel "$jobs" --target "${targets[@]}"
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error --timeout 180 -j 1 -R "$pattern"
