#!/usr/bin/env bash
# Uso: bash scripts/test.sh [Debug|Release] [headless|extended-headless|all].
# headless corresponde ao conjunto Linux da CI oficial. all pode exigir GPU.
operation=test
default_config=Release
source "$(dirname "$0")/container-common.sh"
suite=${2:-headless}
case "$suite" in
  headless|extended-headless)
    targets=(audio_out2_port_tests pad_haptics_tests controller_settings_tests host_input_tests
      ime_dialog_tests lru_cache_tests memory_tracker_tests page_manager_tests
      resource_tracking_tests scalar_provenance_tests resource_materialization_tests
      shader_vertex_metadata_tests archive_file_tests avplayer_file_tests virtual_memory_allocation_tests)
    pattern='^(audio_out2_port|pad_haptics|controller_settings|host_input|ime_dialog|lru_cache|memory_tracker|page_manager|resource_tracking|scalar_provenance|resource_materialization|shader_vertex_metadata|archive_file|avplayer_file|virtual_memory_allocation)$'
    ;;
  all) targets=(kyty_emulator kyty_tests); pattern='.*' ;;
  *) echo 'Suite: headless, extended-headless ou all.' >&2; exit 2 ;;
esac
if [[ $suite == extended-headless ]]; then
  # Existing upstream CPU/mock regressions beyond the CI subset; no game or GPU.
  targets+=(kyty_emulator image_page_table_tests trophy_system_tests vdecsw_tests
    bit_array_tests event_queue_lifetime_tests sync_on_address_tests audio_out_timing_tests
    ngs2_sampler_tests save_data_memory_tests png_enc_tests ces_tests save_data_dialog_tests)
  pattern="($pattern)|^(image_page_table|trophy_system|vdecsw|bit_array|event_queue_lifetime|sync_on_address|audio_out_timing|ngs2_sampler|save_data_memory|png_enc|ces|save_data_dialog|emulator_user_name_cli|emulator_user_name_too_long|emulator_present_mode_cli|emulator_present_mode_invalid|guest_red_zone_patcher)$"
fi
configure
cmake --build "$build_dir" --parallel "$jobs" --target "${targets[@]}"
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error --timeout 180 -j 1 -R "$pattern"
