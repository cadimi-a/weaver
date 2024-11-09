
# Diagram
![diagram.jpg](doc%2Fdiagram.jpg)

# Main Services in Use

| Service Name | Role in Design          | Comments            |
|--------------|-------------------------|---------------------|
| EC2          | Host server for jenkins | Used to run jenkins |

# Prerequisites
- Ensure an active AWS account.
- Install Docker on your local machine.
- Configure a .env file before starting.

# Getting Started

| Step | Command       | Comments                        |
|------|---------------|---------------------------------|
| 1    | `cd scripts`  | Navigate to the scripts folder  |
| 2    | `./init.sh`   | Initiate the Docker container   |
| 3    | `./test.sh`   | Test the OpenTofu codes         |
| 4    | `./deploy.sh` | Deploys the Jenkins environment |
| 5    | `./clean.sh`  | Remove the Jenkins environment  |

# Purpose of This Architecture
- Set up a Jenkins host server on AWS following the steps in the https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/

# Best-Suited Scenarios for This Architecture
- You want to create a small and simple jenkins server in AWS
- You want to get hands-on with jenkins following an official guide in AWS
- It is no problem to place a EC2 instance in a public subnet and to connect ssh using key directly considering requirements

# Potential Alternatives for This Architecture
## Multiple Jenkins Controllers With Multiple Agents in Private Subnets
![diagram-alternative.jpg](doc%2Fdiagram-alternative.jpg)

The architecture in the main diagram exposes the Jenkins instance to the public, which may raise security concerns. Additionally, it lacks scalability. The following setup addresses these limitations and provides several advantages:
- Improved Security: Placing the Jenkins controller and agents in a private subnet helps prevent direct public access to the Jenkins instances.
- Enhanced Access Control: Delegating authentication to the ALB via OpenID Connect, or using AWS Cognito if needed, strengthens security. Adding AWS WAF to the ALB provides additional traffic filtering.
- Enhanced Scalability: This setup supports scaling for both the Jenkins controller and agents, allowing the system to handle increased load more effectively.

# References
- https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/
- https://cloudonaut.io/how-to-set-up-jenkins-on-aws/

#devops #aws #jenkins