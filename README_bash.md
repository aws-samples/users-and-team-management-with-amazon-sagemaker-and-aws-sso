## Setting up the environment

> :warning: The Cloud9 workspace should be built by an IAM user with Administrator privileges, not the root account user. Please ensure you are logged in as an IAM user, not the root account user.

1. Create new Cloud9 Environment
    * Launch Cloud9 in your closest region Ex: `https://us-west-2.console.aws.amazon.com/cloud9/home?region=us-west-2`
    * Select Create environment
    * Name it whatever you want, click Next.
    * Choose “t3.small” for instance type, take all default values and click Create environment
2. Create EC2 Instance Role
    * Follow this [deep link](https://console.aws.amazon.com/iam/home#/roles$new?step=review&commonUseCase=EC2%2BEC2&selectedUseCase=EC2&policies=arn:aws:iam::aws:policy%2FAdministratorAccess) to create an IAM role with Administrator access.
    * Confirm that AWS service and EC2 are selected, then click Next to view permissions.
    * Confirm that AdministratorAccess is checked, then click `Next: Tags` to assign tags.
    * Take the defaults, and click `Next: Review` to review.
    * Enter `Cloud9AdminRole` for the Name, and click `Create role`.
3. Remove managed credentials and attach EC2 Instance Role to Cloud9 Instance
    * Click the gear in the upper right-hand corner of the IDE which opens settings. Click the `AWS Settings` on the left and under `Credentials` slide the button to the left for `AWS managed temporary credentials`. The button should be greyed out when done, indicating it's off.
    * Click the round Button with an alphabet in the upper right-hand corner of the IDE and click `Manage EC2 Instance`. This will take you to the EC2 portion of the AWS Console
    * Right-click the EC2 instance and in the fly-out menu, click `Security` -> `Modify IAM Role`
    * Choose the Role you created in step 3 above. It should be titled `Cloud9AdminRole` and click `Save`.
4. Clone the repo and run the setup script
    * Return to the Cloud9 IDE
    * In the upper left part of the main screen, click the round green button with a `+` on it and click `New Terminal`
    * Enter the following in the terminal window

    ```bash
    git clone https://github.com/aws-samples/users-and-team-management-with-amazon-sagemaker-and-aws-sso.git
    cd users-and-team-management-with-amazon-sagemaker-and-aws-sso
    chmod +x bash_setup.sh
    ./bash_setup.sh

## Cleanup
   > :warning: Close the terminal window that you created the cluster in, and open a new terminal before starting this step otherwise you may get errors about your AWS_REGION not set.
    * Open a **_NEW_** terminal window and `cd` back into `aws-saas-factory-data-isolation-using-hashicorp-vault-in-amazon-eks` and run the following script:

1. The deployed components can be cleaned up by running the following:

    ```bash
    chmod +x bash_cleanup.sh
    ./bash_cleanup.sh
    ```

2. You can also delete

    a. The EC2 Instance Role `Cloud9AdminRole`

    b. The Cloud9 Environment