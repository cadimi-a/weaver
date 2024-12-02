output "api_gateway_url" {
  value       = "${aws_api_gateway_stage.api_gw_stage.invoke_url}/${aws_api_gateway_resource.dynamodb_resource.path_part}"
  description = "API Gateway Invoke URL"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.dynamodb_table.name
  description = "DynamoDB Table Name"
}