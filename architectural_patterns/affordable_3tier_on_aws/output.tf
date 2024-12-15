output "api_gateway_url" {
  value       = "${aws_api_gateway_stage.api_gw_stage.invoke_url}/${aws_api_gateway_resource.api_gw_resource.path_part}"
  description = "API Gateway Invoke URL"
}