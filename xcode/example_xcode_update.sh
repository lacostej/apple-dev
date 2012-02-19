ADC_DIR=../adc
SITE_JSON=${ADC_DIR}/site.json
file=../project.pbxproj
configuration="Ad Hoc"
profile_type="distribution"
profile_name="TestFlight WWTK All Projects"

./xcode_update_pp.sh "${ADC_DIR}" "${SITE_JSON}" "${file}" "${configuration}" "${profile_type}" "${profile_name}"