# Document-Schema

Introduction

- Document-Schema-Deployment is a Repository for deploying the document schema to Development, Test , Sandbox and Prod environments for non actionable flow schemas and deploying the document schema to Development for actionable flow schemas
- It keeps updates about the Tradelens schema version, the deployment and fixbug versions
- The Travis CI build currently supports updating the deployed document schema, so it assumed that a record for the document schema already exists in the csv file with the schema Id [To be changed to support first time document schema deployment ] 
- The release_version, deployment_version and build_version are the implemented versioning system to track the document schema changes. we started our "release_version" with value 1. It won't be changed until business decision is taken. the deployment_version represents the feature versions and build_version represents the fixbug versions.
Ex: HBOL document schema version "1.1.4" ---> we have deployed one feature x ,it had 4 fixbug deployed for this specific feature x in release 1 

Steps to deploy new feature for a document schema :
----------------------------------------------------
1- Create new branch from develop branch that must start with "feature_......"  
Ex: "feature_HBOL_firstdeployment" 

2- Add json file with name "HouseBOL.json" [ the name should be same as the document name in the csv file https://github.com/Eman-Github/Document-Schema-Deployment/blob/develop/document_schema_data.csv ]

3- Commit and push the updated json file on the new branch "feature_HBOL_firstdeployment"  

4- Create pull request from the new branch feature_HBOL_firstdeployment to develop branch 

5- Merge the pull request

6- Check travis CI deployed successfully, the csv file is updated, the version is tagged (1.1.0) and new branch created automatically.


Steps to deploy a fixbug for release 1.1.0:
---------------------------------------------
1- Create new branch from develop branch that must start with "fixbug_releaseVersion.deploymentVersion_....." 
Ex: fixbug_1.1_HBOL_addparamX

2- Add json file with name "HouseBOL.json" [ the name should be same as the document name in the csv file https://github.com/Eman-Github/Document-Schema-Deployment/blob/develop/document_schema_data.csv ]

3- Commit and push the updated json file on the new branch fixbug_1.1_HBOL_addparamX

4- Create pull request from the new branch fixbug_1.1_HBOL_addparamX  to develop branch 

5- Merge the pull request

6- Check travis CI deployed successfully and the csv file is updated, the version is tagged (1.1.1) and new branch created automatically.

For Test env, it will update the versioning only in csv file for actionable flow document schemas

Steps to deploy to Test env. :
--------------------------------
1- Create pull request from branch release/HouseBOL/v1.1.1 (which is created automatically) to test branch

2- When build finishes successfully you can see the csv file updated with the new TL version deployed and the document schema on Test env record updated with v1.1.1
