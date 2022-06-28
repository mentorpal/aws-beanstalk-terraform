## Roles and permissions

### Developer

Needs this infrastructure provisioned, might have AWS account, but does not require AWS permissions to run the terraform.

### Admin

Has sufficient privileges in the relevant AWS account to build all the infrastructure. 
Ideally, has AWS expertise to review infrastructure, with an eye for security and best practices.


## Required Software

 
```
**NOTE** only the `Admin` really needs `terraform` and `terragrunt` installed (to actually deploy the infrastructure). 
```

 The `Admin` MUST have both `terraform` and `terragrunt`. `terragrunt` is a light wrapper over terraform that helps keep terraform DRY, but more importantly for this case, it solves a chicken/egg problem terraform has where you need an s3 state bucket in place to `terraform init`

 The `Developer` with limited AWS perms may also want these tools installed.

 On mac and most linux flavors, you can install both terraform and terragrunt with [homebrew](https://brew.sh/), e.g.

 ```
 brew update
 brew install terraform
 brew install terragrunt
 ```

 Or you check [here for other terraform install methods](https://www.terraform.io/downloads.html) and [here for terragrunt install](https://terragrunt.gruntwork.io/docs/getting-started/install/)


## Required Accounts and Externals

To configure infrastructure for a new mentorpal site using this module you will need the following:

- (`Admin`): an `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for an AWS iam with admin permissions
- (`Admin`): A domain name and SSL certificate for your mentorpal site. Current terraform assumes this is all in AWS with cert in `AWS Certificate Manager` and DNS in `AWS Route 53`), and you must have an instance of the certificate in the same AWS region where you are deploying the app (you can create certs for the same domain in multiple regions with ACM.)
- (`Admin`): optionally a Github organization/account admin access to configure cicd pipelines
- (`Developer`): a `MONGO_URI` for read/write connections to a [mongodb](https://www.mongodb.com/1) instance (you can use a free mongodb.com instance for this to start)
- (`Developer`): a [GOOGLE_CLIENT_ID](https://developers.google.com/identity/one-tap/web/guides/get-google-api-clientid) for google user authentication


## Deploying/Updating the Infrastructure to AWS

Once `Admin` has required external software, domains, certs, etc in hand, follow these steps:

1. make sure AWS credentials are available in shell, e.g.
    > ```bash
    > export AWS_ACCESS_KEY_ID=<your_id>
    > export AWS_SECRET_ACCESS_KEY=<your_secret>
    > ```
2. clone this repo
3. edit `terragrunt.tfvars` with config details for your site
4. create `secret.tfvars` based on `./secret.tfvars.template`
5. edit `terragrunt.hcl` with config details for your site
6. edit `main.tf` with config details for your site
7. (optional) to configure slack notifications: `mv global.tf.template global.tf`
8. run `make apply`
9. when prompted with the terraform plan, you have to enter `yes` to proceed
10. terraform will run for maybe 20 minutes total (waiting for AWS to build things). When if completes successfully, it will create and store required parameters in the SSM (e.g. `CLOUDFRONT_DISTRIBUTION_ID` which you will use to configure your app deployment).
11. optional create a CodeStar-Github connection and approve in Github
12. create SSM parameters. Secret management is external (e.g. maybe secrets were shared via 1password). Required params: 
  - /mentorpal/<env>/shared/api_secret
  - /mentorpal/<env>/shared/jwt_secret
  - /mentorpal/graphql/<env>/mongo_uri
  - /mentorpal/<env>/shared/GOOGLE_CLIENT_ID
  - (optional): /mentorpal/infrastructure/cicd/CODESTAR_GITHUB_ARN
  - (optional): /mentorpal/upload/sentry_dsn, /mentorpal/classifier/sentry_dsn, /mentorpal/graphql/sentry_dsn

The provisioned infrastructure contains resources required to run applications:
 - S3 buckets
 - CDNs
 - firewalls
 - SSM parameters

You can now proceed and deploy the applications (either by provisioning CICD pipelines or manually):
 - https://github.com/mentorpal/sbert-service (no cicd provided yet)
 - https://github.com/mentorpal/mentor-graphql
 - https://github.com/mentorpal/mentor-upload-processor
 - https://github.com/mentorpal/classifier-service
 - https://github.com/mentorpal/mentor-admin
 - https://github.com/mentorpal/mentor-home-page
 - https://github.com/mentorpal/mentor-client

Each application cicd pipeline will read necessary config parameters from SSM. 

 ## FAQ

 ### Why execute the terraform manually rather than in CI?

 Really, it would be better to have `terraform` execute in a CI environment based on some specific trigger (e.g. a tag with a `semver` format from `main`.) The reason we don't do this yet is that it's not trivial to efficiently automate terragrunt applies. 
