#!/bin/bash
set -ev

echo "............script started............"
sleep 1
pwd
result=`python ./scripts/get_version.py "hi"`
echo "result = $result ";
if [ "$result" == "Salaam" ]; then
    echo "script return correct response"
fi

if [ -z $1 ]; then
    echo "CHANGED_FILE can't be null ";
    exit 1;
fi;

if [ -z $2 ]; then
    echo "CHANGED_FILE Name can't be null ";
    exit 1;
fi;

if [ "$TRAVIS_BRANCH" == "develop" ]; then
   API_KEY=$DEV_API_KEY;
   HOST_URL=$DEV_URL;
   SOLUTION_ID="gtd-dev"

elif [ "$TRAVIS_BRANCH" == "test" ]; then
   API_KEY=$TEST_API_KEY;
   HOST_URL=$TEST_URL;
   SOLUTION_ID="gtd-test"

elif [ "$TRAVIS_BRANCH" == "sandbox" ]; then
   API_KEY=$SANDBOX_API_KEY;
   HOST_URL=$SANDBOX_URL;
   SOLUTION_ID="gtd-sandbox"

elif [ "$TRAVIS_BRANCH" == "prod" ]; then
   API_KEY=$PROD_API_KEY;
   HOST_URL=$PROD_URL;
   SOLUTION_ID="gtd-prod"

elif [ "$TRAVIS_BRANCH" == "demo" ]; then
   API_KEY=$DEMO_API_KEY;
   HOST_URL=$DEMO_URL;
   SOLUTION_ID="gtd-demo"

fi;

#Getting the Refresh Access key 
#==============================
HEADER_CONTENT_TYPE="Content-Type:application/x-www-form-urlencoded"
BODY="grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$API_KEY"

echo "parameters = $HEADER_CONTENT_TYPE and $BODY "
RESPONSE_REFRESH_TOKEN=`curl --location --request POST 'https://iam.ng.bluemix.net/oidc/token' --header ${HEADER_CONTENT_TYPE} --data-raw ${BODY}`
echo "RESPONSE_REFRESH_TOKEN = $RESPONSE_REFRESH_TOKEN"

if [ -z $RESPONSE_REFRESH_TOKEN ]; then
    echo "RESPONSE_REFRESH_TOKEN failed to be returned using POST API 'https://iam.ng.bluemix.net/oidc/token' ";
    exit;
fi;
#---------------------------------------------------------------------------------

#Getting Bearer Token
#==============================
HEADER_CONTENT_TYPE="Content-Type:application/json"
HEADER_ACCEPT="Accept:application/json"
URL="$HOST_URL/onboarding/v1/iam/exchange_token/solution/$SOLUTION_ID/organization/gtd-ibm-authority"
echo "URL = $URL"

RESPONSE_BEARER=`curl --location --request POST "$URL" \
--header ${HEADER_CONTENT_TYPE} \
--header ${HEADER_ACCEPT} \
--data-raw "${RESPONSE_REFRESH_TOKEN}"`

#echo "RESPONSE_BEARER = $RESPONSE_BEARER"

BEARER_TOKEN=`echo $RESPONSE_BEARER | grep -oP '(?<="onboarding_token":")[^"]*'`
echo "BEARER_TOKEN = $BEARER_TOKEN"

if [ -z $$RESPONSE_BEARER ]; then
    echo "RESPONSE_BEARER failed to be returned using API $URL ";
    exit;
fi; 

#-----------------------------------------------------------------------------------
#Call API to deploy the Document Schema on Development Env. 
#============================================================
HEADER_CONTENT_TYPE="Content-Type:application/json"
HEADER_ACCEPT="Accept:application/json"
HEADER_AUTHORIZATION="Authorization: Bearer $BEARER_TOKEN"
POST_API_URL="$HOST_URL/api/v1/documentSchema"
echo "POST_API_URL = $POST_API_URL"

#------------------- Deploy to Development env. --------------
if [ "$TRAVIS_BRANCH" == "develop" ]; then
   
   JSON_FILE=`cat "${1}"`
   echo "$JSON_FILE"
   POST_RESPONSE=`curl --location --request POST "$POST_API_URL" \
      --header "${HEADER_CONTENT_TYPE}" \
      --header "${HEADER_AUTHORIZATION}" \
      --data-raw "${JSON_FILE}"`
      
      echo "POST_RESPONSE = $POST_RESPONSE";
      if echo "$POST_RESPONSE" | grep -q "id"; then
         echo "POST Schema API run successfully";
         declare -i DOC_ID=`echo $POST_RESPONSE | grep -oP '(?<="id":)[^,]*'`
         echo "DOC_ID_DEV = $DOC_ID_DEV"
         for i in {1..10}
         do
            sleep 5s
         done 

         GET_RESPONSE=`curl --location --request GET "$API_URL/$DOC_ID_DEV" \
         --header "${HEADER_AUTHORIZATION}"`
         echo "GET_RESPONSE = $GET_RESPONSE"

         declare -i TL_VERSION_DEV=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
         echo " TL_VERSION_DEV = $TL_VERSION_DEV"
    
         CURRENT_DATE=`date +'%Y-%m-%d %T'`
         echo "CURRENT_DATE = $CURRENT_DATE"
         NEWLINE="${2},${TRAVIS_BRANCH},${CURRENT_DATE},$DOC_ID,$TL_VERSION_DEV,1,0,0";
         echo "$NEWLINE"  >> ./document_schema_data.csv
          head -n 1 ./document_schema_data.csv > ./temp.csv &&
          tail -n +2 ./document_schema_data.csv | sort -t "," -k 1 >> ./temp.csv
          cp ./temp.csv ./document_schema_data.csv
          rm ./temp.csv
          cat ./document_schema_data.csv

          git status
          git add ./document_schema_data.csv
          git commit -m "Auto update versions"
          git show-ref
          git branch
          git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"$TRAVIS_BRANCH"

      else
         echo "API for post the documentSchema $API_URL name = ${2} has failed to deploy ";
         exit 1;
      fi;   
#------------------- Get Current TL Version on Test env. --------------
elif [ "$TRAVIS_BRANCH" == "test" || "$TRAVIS_BRANCH" == "sandbox" || "$TRAVIS_BRANCH" == "demo" || "$TRAVIS_BRANCH" == "prod"]; then

   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then
 
       JSON_FILE=`cat "${1}"`
       echo "$JSON_FILE"

       #   POST_RESPONSE=`curl --location --request POST "$POST_API_URL" \
       #      --header "${HEADER_CONTENT_TYPE}" \
       #      --header "${HEADER_AUTHORIZATION}" \
       #      --data-raw "${JSON_FILE}"`

      echo "POST_RESPONSE = $POST_RESPONSE";
      if echo "$POST_RESPONSE" | grep -q "id"; then
         echo "POST Schema API run successfully";
         declare -i DOC_ID=`echo $POST_RESPONSE | grep -oP '(?<="id":)[^,]*'`
         echo "DOC_ID_DEV = $DOC_ID_DEV"
         for i in {1..10}
         do
            sleep 5s
         done
         
          GET_RESPONSE=`curl --location --request GET "$API_URL/$DOC_ID_DEV" \
         --header "${HEADER_AUTHORIZATION}"`
         echo "GET_RESPONSE = $GET_RESPONSE"

         declare -i TL_VERSION_DEV=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
         echo " TL_VERSION_DEV = $TL_VERSION_DEV"

         CURRENT_DATE=`date +'%Y-%m-%d %T'`
         echo "CURRENT_DATE = $CURRENT_DATE"
       #  DOC_NAME = ${file%.json}
         NEWLINE="${2},${TRAVIS_BRANCH},${CURRENT_DATE},$DOC_ID,$TL_VERSION_DEV,1,0,0";
         echo "$NEWLINE"  >> ./document_schema_data.csv
         head -n 1 ./document_schema_data.csv > ./temp.csv &&
          tail -n +2 ./document_schema_data.csv | sort -t "," -k 1 >> ./temp.csv
          cp ./temp.csv ./document_schema_data.csv
          rm ./temp.csv
          cat ./document_schema_data.csv

          git status
          git add ./document_schema_data.csv
          git commit -m "Auto update versions"
          git show-ref
          git branch
          git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"$TRAVIS_BRANCH"
          git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"develop"
      else
         echo "API for post the documentSchema $API_URL name = ${2} has failed to deploy ";
         exit 1;
      fi;     
   fi;
fi;

#-----------------------------------------------------------------------------------
