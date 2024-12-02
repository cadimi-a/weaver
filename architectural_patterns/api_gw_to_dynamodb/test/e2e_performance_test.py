import requests
import time
from concurrent.futures import ThreadPoolExecutor

# Function to read the config file
def read_config(filename):
    config = {}
    with open(filename, "r") as file:
        for line in file:
            key, value = line.strip().split(" = ", 1)
            config[key.strip()] = value.strip().strip('"')  # Remove quotes
    return config

# Read the configuration
config = read_config("../output.txt")
api_gateway_url = config.get("api_gateway_url")
dynamodb_table_name = config.get("dynamodb_table_name")

# Define the ingestion function
def upload_row(data):
    start_time = time.time()
    response = requests.post(api_gateway_url, json=data)
    elapsed_time = time.time() - start_time
    return response.status_code, elapsed_time

# Create dummy data
dummy_data = [
    {"pageId": f"test_page_id_{i}", "userName": f"User_{i}", "message": f"test message {i}"}
    for i in range(1, 101)
]

# Add timestamps and test performance
def ingestion_test(data_batch, batch_number, metrics):
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = []
        for row in data_batch:
            row["timestamp"] = time.time()  # Add timestamp dynamically
            row["table_name"] = dynamodb_table_name  # Add table name from config
            futures.append(executor.submit(upload_row, row))

        start_time = time.time()
        results = [future.result() for future in futures]  # Wait for all threads to complete
        end_time = time.time()

        # Track batch metrics
        success_count = sum(1 for status_code, _ in results if status_code == 200)
        avg_time = sum(elapsed_time for _, elapsed_time in results) / len(results)
        total_time = end_time - start_time

        metrics["total_requests"] += len(results)
        metrics["total_success"] += success_count
        metrics["total_time"] += total_time
        metrics["batch_total_times"].append(total_time)  # Track batch total time
        metrics["average_response_time"].append(avg_time)

        # Log results for this batch
        print(f"Batch {batch_number} results:")
        for status_code, elapsed_time in results:
            print(f"Status: {status_code}, Time: {elapsed_time:.2f}s")
        print(f"Total time for batch: {total_time:.2f}s")
        print(f"Success rate for batch: {success_count / len(results) * 100:.2f}%")
        print(f"Average Response Time: {avg_time:.2f}s\n")

# Initialize metrics
metrics = {
    "total_requests": 0,
    "total_success": 0,
    "total_time": 0,
    "batch_total_times": [],
    "average_response_time": [],
}

# Split data into batches of 10
for batch_number, i in enumerate(range(0, len(dummy_data), 10), start=1):
    ingestion_test(dummy_data[i:i + 10], batch_number, metrics)
    time.sleep(1)  # Ensure batches are sent 1 second apart

# Calculate final metrics
overall_success_rate = metrics["total_success"] / metrics["total_requests"] * 100
overall_average_time = sum(metrics["average_response_time"]) / len(metrics["average_response_time"])
total_requests = metrics["total_requests"]
total_time_taken = metrics["total_time"]
batch_average_total_time = sum(metrics["batch_total_times"]) / len(metrics["batch_total_times"])

# Write results to file
result_file = "result_e2e_performance_test.txt"
with open(result_file, "w") as file:
    file.write("E2E Performance Test Results====================================================\n")
    file.write(f"Total Requests: {total_requests}\n")
    file.write(f"Total Success: {metrics['total_success']}\n")
    file.write(f"Overall Success Rate: {overall_success_rate:.2f}%\n")
    file.write(f"Total Time Taken: {total_time_taken:.2f}s\n")
    file.write(f"Overall Average Response Time: {overall_average_time:.2f}s\n")
    file.write(f"Batch Average Total Time: {batch_average_total_time:.2f}s\n")
    file.write("\nBatch Total Times:\n")
    for batch_num, batch_time in enumerate(metrics["batch_total_times"], start=1):
        file.write(f"Batch {batch_num}: {batch_time:.2f}s\n")

print(f"Test results have been written to {result_file}")
