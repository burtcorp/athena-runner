# athena-runner

A demonstration of how to use AWS Step Functions to run an Athena query and handle the results, without idling while waiting for it to finish.

## Setup

The following assumes you're running in us-east-1. If you're not you need to change `config/policies/TrustRelationship.json` to your region, and set the `AWS_REGION` environment variable when running the commands below.

Make sure the `aws` command has access to your credentials, either by adding them to `~/.aws/config` or by setting environment variables, like this:

```shell
$ export AWS_ACCESS_KEY_ID=…
$ export AWS_SECRET_ACCESS_KEY=…
```

The following command will install dependencies, create an execution role called "athena-runner", create three Lambda functions all prefixed by "athena-runner-", and a Step Functions state machine called "athena-runner".

```shell
$ make deps create-role create-functions create-state-machine
```

The execution role created by the command above will have policies that allows it to be used by Lambda and Step Functions to execute Athena queries, store the result in the standard Athena query results S3 bucket, log to CloudWatch Logs, etc. The policies are located in `config/policies`.

It does not have permissions to read anything on S3 outside of the standard Athena query results bucket, though. To make it possible to actually execute Athena queries you must also grant it access to the underlying data on S3. This can be done by adding a policy file to `config/policies` similar to the one below:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket/the/table/location/*"
      ]
    }
  ]
}
```

Change "my-bucket" and "the/table/location" with the bucket and location within the bucket where the table's data is stored. This should be more or less the same as the `LOCATION s3://…` part of the Athena table definition.

Once you've created the policy file run the following command to add it to the execution role:

```shell
$ make update-role
```

This will sync all files in `config/policies` (except `TrustRelationship.json`) as policies on the execution role.

## Run the state machine

Step Functions are most fun when you run them from the AWS console, because you get the pretty state machine visualization and can follow along as the steps execute. Go to the console and create an execution with the following input:

```json
{
  "query": "SELECT COUNT(*) FROM my_database.my_table",
  "outputLocation": "s3://aws-athena-query-results-1234567890-us-east-1/athena-runner/"
}
```

Change "my_database.my_table" to the name of the table you want to query, and change "1234567890" in the bucket name to your account ID.

If you don't care for pretty visualizations you can execute the state machine from the command line:

```shell
$ input='{"query":"SELECT COUNT(*) FROM my_table","outputLocation":"s3://aws-athena-query-results-1234567890-us-east-1/athena-runner/"}'
$ aws stepfunctions start-execution --state-machine-arn $(cat config/state-machine-arn) --input "$input"
```

Capture the execution ARN and follow the status with `aws stepfunctions describe-execution --execution-arn …`.

# Copyright

© 2017 Burt AB, see LICENSE.txt (BSD 3-Clause)
