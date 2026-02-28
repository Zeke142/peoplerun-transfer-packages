EM_DELTA=$(( EM_MAX - EM_MIN ))
if [ "${BOOT_FALSE:-0}" -ne 0 ]; then
  echo "RESULT: FAIL — boot_ok was false at least once in the window."
fi
if [ "${EM_DELTA:-0}" -lt 1 ]; then
  echo "RESULT: FAIL — no emission observed during the window while boot_ok remained true."
fi
