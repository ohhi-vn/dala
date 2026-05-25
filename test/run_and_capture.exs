# Run tests and capture output to a file
defmodule TestCapture do
  def run do
    # Ensure the application is started
    Application.ensure_all_started(:dala)

    # Run tests
    output = ExUnit.run()

    # Write results
    File.write!(
      "/Users/manhvu/ohhi/OSS_Lib/dala/test_capture_output.txt",
      "Test run completed: #{inspect(output)}"
    )
  end
end

# Configure ExUnit
ExUnit.start(max_cases: 10)

# Run tests
TestCapture.run()
