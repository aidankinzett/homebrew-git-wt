# Mock implementation of bats-assert load
assert_output() {
  local partial=false
  if [[ "$1" == "--partial" ]]; then
    partial=true
    shift
  fi

  local expected="$1"

  if [[ "$partial" == "true" ]]; then
    if [[ "$output" != *"$expected"* ]]; then
      echo "expected output to contain: $expected"
      echo "actual output: $output"
      return 1
    fi
  else
    if [[ "$output" != "$expected" ]]; then
      echo "expected output: $expected"
      echo "actual output: $output"
      return 1
    fi
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "expected failure, but succeeded"
    return 1
  fi
}
