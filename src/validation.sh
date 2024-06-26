# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck source=summary.sh
. "${SCRIPT_DIR=}summary.sh"

WORK_DIR="${WORK_DIR-../}"

# Get file containing fixes based on two input files
# $1 - <string> absolute path to a file containing results from BASE scan
# $2 - <string> absolute path to a file containing results from HEAD scan
# $? - return value - 0 on success
# results are returned in file - '../fixes.log'
get_fixes () {
  [[ $# -le 1 ]] && return 1

  csdiff --fixed "${1}" "${2}" > "${WORK_DIR}fixes.log"
}

# Function to evaluate results of fixed defects and to provide feedback on standard output
# It expects file '../fixes.log' to contain fixes
# $? - return value is always 0
evaluate_and_print_fixes () {
  gather_statistics "${WORK_DIR}fixes.log"

  num_of_fixes=$(get_number_of fixes)
  if [[ "${num_of_fixes}" -gt 0 ]]; then
    echo -e "✅ ${GREEN}Fixed defects${NOCOLOR}"
    csgrep --embed-context 2 "${WORK_DIR}fixes.log"
  else
    echo -e "ℹ️ ${YELLOW}No Fixes!${NOCOLOR}"
  fi
}

# Get file containing defects based on two input files
# $1 - <string> absolute path to a file containing results from HEAD scan
# $2 - <string> absolute path to a file containing results from BASE scan
# $? - return value - 0 on success
# results are returned in file - '../defects.log'
get_defects () {
  [[ $# -le 1 ]] && return 1

  csdiff --fixed "${1}" "${2}" > "${WORK_DIR}defects.log"
}

# Function to evaluate results of defects and to provide feedback on standard output
# It expects file '../defects.log' to contain defects
# $? - return value - 0 on success
evaluate_and_print_defects () {
  gather_statistics "${WORK_DIR}defects.log"

  num_of_defects=$(get_number_of defects)
  if [[ "${num_of_defects}" -gt 0 ]] ; then
    print_statistics

    echo -e "✋ ${YELLOW}Defects, NEEDS INSPECTION${NOCOLOR}"
    csgrep --embed-context 4 "${WORK_DIR}defects.log"
    return 1
  fi

  echo -e "🥳 ${GREEN}No defects added. Yay!${NOCOLOR}"
}

# Function to print statistics of defects
# it requires gather_statistics to be called first
print_statistics () {
  echo -e "::group::📊 ${WHITE}Statistics of defects${NOCOLOR}"
    [[ -n ${stat_error} ]] && echo -e "Error: ${stat_error}"
    [[ -n ${stat_warning} ]] && echo -e "Warning: ${stat_warning}"
    [[ -n ${stat_info} ]] && echo -e "Style or Note: ${stat_info}"
  echo "::endgroup::"
  echo
}

# Function to filter out defects by their severity level
# It sets global variables stat_error, stat_warning, stat_info depending on INPUT_SEVERITY
# $1 - <string> absolute path to a file containing defects detected by scan
gather_statistics () {
  [[ $# -le 0 ]] && return 1
  local logs="$1"

  [[ ${INPUT_SEVERITY-} =~ style|note ]] && stat_info=$(get_number_of_defects_by_severity "info" "${logs}")
  [[ ${INPUT_SEVERITY} =~ style|note|warning ]] && stat_warning=$(get_number_of_defects_by_severity "warning" "${logs}")
  [[ ${INPUT_SEVERITY} =~ style|note|warning|error ]] && stat_error=$(get_number_of_defects_by_severity "error" "${logs}")

  export stat_info stat_warning stat_error
}

# Function to get number of defects by severity level
# $1 - <string> severity level
# $2 - <string> absolute path to a file containing defects detected by scan
get_number_of_defects_by_severity () {
  [[ $# -le 1 ]] && return 1
  local severity="$1"
  local logs="$2"
  local defects=0

  [[ -f "${logs}" ]] || return 1
  # the optional group is workaround for csdiff issue: https://github.com/csutils/csdiff/issues/138
  defects=$(grep --count --extended-regexp "^\s*\"event\": \"${severity}\[SC[0-9]+\]\",$" "${logs}")
  echo "${defects}"
}
