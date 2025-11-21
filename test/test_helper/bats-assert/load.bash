# Mock implementation of bats-assert load
assert_output() {
  local partial=false
  if [[ "$1" == "--partial" ]]; then
    partial=true
    shift
  fi

  local expected="$1"
  if [[ "$output" == "" ]]; then
      # If output is empty, it might be captured in a different way or the test failed earlier.
      # However, for our mock implementation, we check against the global output variable.
      :
  fi

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
