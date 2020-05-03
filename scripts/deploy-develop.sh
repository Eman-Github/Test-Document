#!/bin/bash
set -ev

if [ -z $1 ]; then
    echo "CHANGED_FILE can't be null ";
    exit;
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
#------------------------------------------------------------------------------------
#Get the Document Schema Id from document_schema_data.csv file
#==============================================================

echo "Get the Document Schema Id from document_schema_data.csv file '$1' ";
temp=${1#*/}
CHANGED_DOC_NAME=${temp%.*}
echo "Document Name $CHANGED_DOC_NAME"
echo "${CHANGED_DOC_NAME},${TRAVIS_BRANCH}"
#grep "${CHANGED_DOC_NAME},${TRAVIS_BRANCH}" ./document_schema_data.csv || :
#echo "Result1 = ${PIPESTATUS[0]} , Result 2 = ${PIPESTATUS[1]}"
#if [[ "${PIPESTATUS[0]}" == "0" ]];then
  
#   echo "Document Schema ${CHANGED_DOC_NAME} doesn't deployed on branch ${TRAVIS_BRANCH} previously";
#   #echo "Please use POST API to create the schema first and get the schema ID"
#   SCHEMA_FOUND="false";
#else
   LINE=`grep "${CHANGED_DOC_NAME},${TRAVIS_BRANCH}" ./document_schema_data.csv`;
#   SCHEMA_FOUND="true";
#fi;

echo "LINE = $LINE"
#echo "SCHEMA_FOUND = $SCHEMA_FOUND"

IFS=',' read -r -a data <<< "$LINE"

for i in "${!data[@]}"
do
   echo "$i ${data[i]}"
done

#-----------------------------------------------------------------------------------
#Call API to deploy the Document Schema on Development Env. 
#============================================================
HEADER_CONTENT_TYPE="Content-Type:application/json"
HEADER_ACCEPT="Accept:application/json"
HEADER_AUTHORIZATION="Authorization: Bearer $BEARER_TOKEN"
API_URL="$HOST_URL/api/v1/documentSchema/${data[3]}"
POST_API_URL="$HOST_URL/api/v1/documentSchema"
echo "API_URL = $API_URL"
echo "POST_API_URL = $POST_API_URL"

#------------------- Deploy to Development env. --------------
if [ "$TRAVIS_BRANCH" == "develop" ]; then
   
   JSON_FILE=`cat "${1}"`
   echo "$JSON_FILE"
   
#   if [[ $SCHEMA_FOUND == "true" ]]; then
   
      UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
      --header "${HEADER_CONTENT_TYPE}" \
      --header "${HEADER_AUTHORIZATION}" \
      --data-raw "${JSON_FILE}"`
      
      echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
      if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
         echo "Update Schema API run successfully";
      else
         echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
      exit;
      fi;

#   elif [[ $SCHEMA_FOUND == "false" ]]; then
      
      #UPDATE_RESPONSE=`curl --location --request POST "$POST_API_URL" \
      #--header "${HEADER_CONTENT_TYPE}" \
      #--header "${HEADER_AUTHORIZATION}" \
      #--data-raw "${JSON_FILE}"`   

#     UPDATE_RESPONSE={"id":"1111111111",};
#     echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";

#      if echo "$UPDATE_RESPONSE" | grep -q "id"; then
#         echo "Update Schema API run successfully";
#         declare -i TL_SCHEMA_ID=`echo $GET_RESPONSE | grep -oP '(?<="id":)[^,]*'`
#         echo "In TL_SCHEMA_ID = $TL_SCHEMA_ID"
#         POST_API_URL_ID = "$POST_API_URL"\"$TL_SCHEMA_ID"
#         GET_RESPONSE=`curl --location --request GET "$POST_API_URL_ID" \
#         --header "${HEADER_AUTHORIZATION}"`
#         echo "GET_RESPONSE = $GET_RESPONSE"

#         declare -i TL_VERSION_DEV=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
#         echo "In TL_VERSION_DEV = $TL_VERSION_DEV"
#         CURRENT_DATE=`date +'%Y-%m-%d %T'`
#         echo "CURRENT_DATE = $CURRENT_DATE"
#         NEWLINE="${CHANGED_DOC_NAME},$TRAVIS_BRANCH,${CURRENT_DATE},$TL_SCHEMA_ID,$TL_VERSION_DEV,1,1,0";
#         echo "$NEWLINE"  >> ./document_schema_data.csv
#         head -n 1 ./document_schema_data.csv > ./temp.csv &&
#         tail -n +2 ./document_schema_data.csv | sort -t "," -k 1 >> ./temp.csv
#         cp ./temp.csv ./document_schema_data.csv
#         rm ./temp.csv
#         cat ./document_schema_data.csv

#         git status
#         git add ./document_schema_data.csv
#         git commit -m "Auto update versions"
#         git show-ref
#         git branch
#         git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"$TRAVIS_BRANCH"
#         exit 0;

#      else
#         echo "API for deploy the documentSchema POST_API_URL ${CHANGED_DOC_NAME} has failed";
#         exit;
#      fi;

#   fi;
   
   for i in {1..10}
   do
      sleep 5s
   done 

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_DEV=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_DEV = $TL_VERSION_DEV"
   exit $TL_VERSION_DEV

#------------------- Get Current TL Version on Test env. --------------
elif [ "$TRAVIS_BRANCH" == "test" ]; then

   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then
 
       JSON_FILE=`cat "${1}"`
       echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

       echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           exit;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;
   
   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_TEST=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_TEST = $TL_VERSION_TEST"
   exit $TL_VERSION_TEST

#------------------- Get Current TL Version on SandBox env. --------------
elif [ "$TRAVIS_BRANCH" == "sandbox" ]; then
   
   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then

       JSON_FILE=`cat "${1}"`
       echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

       echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           exit;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_SANDBOX=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_SANDBOX = $TL_VERSION_SANDBOX"
   exit $TL_VERSION_SANDBOX

#------------------- Get Current TL Version on Prod env. --------------
elif [ "$TRAVIS_BRANCH" == "prod" ]; then

   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then

       JSON_FILE=`cat "${1}"`
       echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

       echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           exit;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_PROD=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_PROD = $TL_VERSION_PROD"
   exit $TL_VERSION_PROD

#------------------- Get Current TL Version on Demo env. --------------
elif [ "$TRAVIS_BRANCH" == "demo" ]; then
   
   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then

       JSON_FILE=`cat "${1}"`
       echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

       echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           exit;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_DEMO=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_DEMO = $TL_VERSION_DEMO"
   exit $TL_VERSION_DEMO  

fi;

#-----------------------------------------------------------------------------------

