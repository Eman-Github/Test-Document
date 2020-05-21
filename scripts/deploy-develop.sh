#!/bin/bash
set -ev

if [ -z $1 ]; then
    echo "CHANGED_FILE can't be null, NO Schema Json File changed ";
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
#echo "RESPONSE_REFRESH_TOKEN = $RESPONSE_REFRESH_TOKEN"

if [ -z $RESPONSE_REFRESH_TOKEN ]; then
    echo "RESPONSE_REFRESH_TOKEN failed to be returned using POST API 'https://iam.ng.bluemix.net/oidc/token' ";
    exit 1;
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
#echo "BEARER_TOKEN = $BEARER_TOKEN"

if [ -z $$RESPONSE_BEARER ]; then
    echo "RESPONSE_BEARER failed to be returned using API $URL ";
    exit 1;
fi; 
#------------------------------------------------------------------------------------
#Get the Document Schema Id from document_schema_data.csv file
#==============================================================

echo "Get the Document Schema Id from document_schema_data.csv file '$1' ";
temp=${1#*/}
CHANGED_DOC_NAME=${temp%.*}
echo "Document Name $CHANGED_DOC_NAME"
echo "${CHANGED_DOC_NAME},${TRAVIS_BRANCH}"

DOCUMENTS_NAMES=`cut -d "," -f 1,2 document_schema_data.csv`;
DOCUMENTS_NAMES_ARRAY=($DOCUMENTS_NAMES);
len=${#DOCUMENTS_NAMES_ARRAY[@]};
echo "$CHANGED_DOC_NAME,$TRAVIS_BRANCH";
for ((i = 0; i < $len; i++)); do
   #  echo "Document name,branch  = ${DOCUMENTS_NAMES_ARRAY[$i]} ";
     if [[ ${DOCUMENTS_NAMES_ARRAY[$i]} == "$CHANGED_DOC_NAME,$TRAVIS_BRANCH" ]] ; then
      
       ((LINE_NUM=$i+1));
       echo "LINE_NUM = $LINE_NUM" 
       LINE=`sed -n "$LINE_NUM p" ./document_schema_data.csv`;
       echo "LINE = $LINE" 
     fi;
done;

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
declare -i TL_VERSION=0

#------------------- Deploy to Development env. --------------
if [ "$TRAVIS_BRANCH" == "develop" ]; then
   
#   JSON_FILE=`cat "${1}"`
#   echo "$JSON_FILE"
  
#      UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
#      --header "${HEADER_CONTENT_TYPE}" \
#      --header "${HEADER_AUTHORIZATION}" \
#      --data-raw "${JSON_FILE}"`
      
    #  echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
      if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
         echo "Update Schema API run successfully";
      else
         echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
         echo "PUT API Response : ";
         echo "$UPDATE_RESPONSE";
   #      exit 1;
      fi;

   for i in {1..10}
   do
      sleep 5s
   done 

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   #echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_DEV=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_DEV = $TL_VERSION_DEV"
   if [ -z $TL_VERSION_DEV ]; then
    echo "Couldn't get the new version";
    echo "GET API Response :  ";
    echo "$GET_RESPONSE";
    exit 1;
   fi;
   TL_VERSION=$TL_VERSION_DEV;

#------------------- Get Current TL Version on Test env. --------------
elif [ "$TRAVIS_BRANCH" == "test" ]; then

   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then
 
       JSON_FILE=`cat "${1}"`
    #   echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

     #  echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           echo "PUT API Response : ";
           echo "$UPDATE_RESPONSE";
           exit 1;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;
   
   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   #echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_TEST=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_TEST = $TL_VERSION_TEST"
   if [ -z $TL_VERSION_TEST ]; then
    echo "Couldn't get the new version";
    echo "GET API Response :  ";
    echo "$GET_RESPONSE";
    exit 1;
   fi;
  TL_VERSION=$TL_VERSION_TEST;
#------------------- Get Current TL Version on SandBox env. --------------
elif [ "$TRAVIS_BRANCH" == "sandbox" ]; then
   
   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then

       JSON_FILE=`cat "${1}"`
    #   echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

     #  echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           echo "PUT API Response : ";
           echo "$UPDATE_RESPONSE";
           exit 1;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   #echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_SANDBOX=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_SANDBOX = $TL_VERSION_SANDBOX"
   if [ -z $TL_VERSION_SANDBOX ]; then
    echo "Couldn't get the new version";
    echo "GET API Response :  ";
    echo "$GET_RESPONSE";
    exit 1;
   fi;
  TL_VERSION=$TL_VERSION_SANDBOX;
#------------------- Get Current TL Version on Prod env. --------------
elif [ "$TRAVIS_BRANCH" == "prod" ]; then

   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then

       JSON_FILE=`cat "${1}"`
    #   echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

     #  echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           echo "PUT API Response : ";
           echo "$UPDATE_RESPONSE";
           exit 1;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
   #echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_PROD=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_PROD = $TL_VERSION_PROD"
   if [ -z $TL_VERSION_PROD ]; then
    echo "Couldn't get the new version";
    echo "GET API Response :  ";
    echo "$GET_RESPONSE";
    exit 1;
   fi;
   TL_VERSION=$TL_VERSION_PROD;

#------------------- Get Current TL Version on Demo env. --------------
elif [ "$TRAVIS_BRANCH" == "demo" ]; then
   
   DOC_ACTIONABLE_FLOWS=`grep "${CHANGED_DOC_NAME}" ./config.ini`
   echo "DOC_ACTIONABLE_FLOWS = $DOC_ACTIONABLE_FLOWS"
   if [[ ! -z $DOC_ACTIONABLE_FLOWS ]]; then

       JSON_FILE=`cat "${1}"`
    #   echo "$JSON_FILE"

       UPDATE_RESPONSE=`curl --location --request PUT "$API_URL" \
       --header "${HEADER_CONTENT_TYPE}" \
       --header "${HEADER_AUTHORIZATION}" \
       --data-raw "${JSON_FILE}"`

     #  echo "UPDATE_RESPONSE = $UPDATE_RESPONSE";
       if echo "$UPDATE_RESPONSE" | grep -q "${data[3]}"; then
           echo "Update Schema API run successfully";
       else
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           echo "API for uppdating the documentSchema $API_URL name = ${CHANGED_DOC_NAME} has failed to deploy ";
           echo "PUT API Response : ";
           echo "$UPDATE_RESPONSE";
           exit 1;
       fi;

       for i in {1..10}
       do
          sleep 5s
       done
   fi;

   GET_RESPONSE=`curl --location --request GET "$API_URL" \
   --header "${HEADER_AUTHORIZATION}"`
  # echo "GET_RESPONSE = $GET_RESPONSE"

   declare -i TL_VERSION_DEMO=`echo $GET_RESPONSE | grep -oP '(?<="version":)[^,]*'`
   echo "In TL_VERSION_DEMO = $TL_VERSION_DEMO"
   if [ -z $TL_VERSION_DEMO ]; then
    echo "Couldn't get the new version";
    echo "GET API Response :  ";
    echo "$GET_RESPONSE";
    exit 1;
   fi; 
   TL_VERSION=$TL_VERSION_DEMO;
fi;

echo "TL_VERSION = $TL_VERSION"
#-----------------------------------------------------------------------------------
#--------- Update the CSV file -------------------------------------------------
if [[ $TL_VERSION != 0 ]]; then
    FIRSTLINE=(${TRAVIS_COMMIT_MESSAGE[@]})
    temp1=${FIRSTLINE[5]}
    echo "temp1 = $temp1"

    FROM_BRANCH_NAME=${temp1#*/}
    FROM_BRANCH=${TRAVIS_COMMIT_MESSAGE}
    TO_BRANCH=$TRAVIS_BRANCH

    echo "commit message: $FROM_BRANCH"
    echo "From Branch: $FROM_BRANCH_NAME"
    echo "To Branch: $TO_BRANCH"

    #Get the Document Schema versions from document_schema_data.csv file
    #==============================================================

    echo "Get the Document Schema Id from document_schema_data.csv file '$1' ";
    #temp=${1#*/}
    #CHANGED_DOC_NAME=${temp%.*}
    #echo "Document Name $CHANGED_DOC_NAME"
    #echo "${CHANGED_DOC_NAME},${TO_BRANCH}"
    #TO_LINE=`grep "${CHANGED_DOC_NAME},${TO_BRANCH}" ./document_schema_data.csv`
    #echo "TO_LINE = $TO_LINE"


    temp=${1#*/}
    CHANGED_DOC_NAME=${temp%.*}
    echo "Document Name $CHANGED_DOC_NAME"
    echo "${CHANGED_DOC_NAME},${TO_BRANCH}"

    DOCUMENTS_NAMES=`cut -d "," -f 1,2 document_schema_data.csv`;
    DOCUMENTS_NAMES_ARRAY=($DOCUMENTS_NAMES);
    len=${#DOCUMENTS_NAMES_ARRAY[@]};
    echo "$CHANGED_DOC_NAME,$TRAVIS_BRANCH";
    for ((i = 0; i < $len; i++)); do
         echo "Document name,branch  = ${DOCUMENTS_NAMES_ARRAY[$i]} ";
         if [[ ${DOCUMENTS_NAMES_ARRAY[$i]} == "$CHANGED_DOC_NAME,$TO_BRANCH" ]] ; then

           ((LINE_NUM=$i+1));
           echo "LINE_NUM = $LINE_NUM"
           TO_LINE=`sed -n "$LINE_NUM p" ./document_schema_data.csv`;
           echo "TO_LINE = $TO_LINE"
         fi;
    done;
    #------------- Get From Branch Data In case of fixbug ------------
    if [[ "$FROM_BRANCH" == *"fixbug"* ]] ; then
       IFS='_' read -r -a FIXBUG_NAME <<< "$FROM_BRANCH_NAME"
       for i in "${!FIXBUG_NAME[@]}"
       do
          echo "$i ${FIXBUG_NAME[i]}"
          if (($i == 1)) ; then
             IFS='.' read -r -a RELEASE_NUM <<< "${FIXBUG_NAME[i]}"
             for j in "${!RELEASE_NUM[@]}"
             do
               echo "$j ${RELEASE_NUM[j]}"
               if (($j == 0)) ; then
                  BUG_RELEASE_VERSION="${RELEASE_NUM[j]}"
                  echo "BUG_RELEASE_VERSION = $BUG_RELEASE_VERSION"
               elif (($j == 1)) ; then
                  BUG_DEPLOYMNET_VERSION="${RELEASE_NUM[j]}"
                  echo "BUG_DEPLOYMNET_VERSION = $BUG_DEPLOYMNET_VERSION"
               fi;
             done
          fi;
       done     
       
       while read line
       do 
          echo "line = $line"
          IFS=',' read -r -a line_data <<< "$line"
          for i in "${!line_data[@]}"
          do
             echo "$i ${line_data[i]}"
             if (($i == 6)) ; then
                if [[ "${line_data[i]}" == "$BUG_DEPLOYMNET_VERSION" ]]; then
                  current_deployment_version="${line_data[i]}"
                  current_deployment_line="$line"
                fi;
             fi;

          done

       done <<< "$TO_LINE"
    #-------- Get the deployment and build Line of document to be updated in case of feature ------------------------------------
    elif [[ "$FROM_BRANCH" == *"feature"* ]] ; then
      
       current_deployment_version=-1
       while read line
       do
         echo "line = $line"
         IFS=',' read -r -a line_data <<< "$line"
         for i in "${!line_data[@]}"        
         do
           echo "$i ${line_data[i]}"
           if (($i == 6)) ; then
                 echo "Inside current_deployment_version = $current_deployment_version"
            #  if [[ "$current_deployment_version" == "e" ]]; then
            #    current_deployment_version="${line_data[i]}"
            #    current_deployment_line="$line"
              if [[ "${line_data[i]}" -gt "$current_deployment_version" ]]; then
                current_deployment_version="${line_data[i]}"
                current_deployment_line="$line"
              fi;
           fi;
         done

       done <<< "$TO_LINE"   
    fi;
    #------------------------------------------------------------------------
    if [[ "$FROM_BRANCH" != *"feature"* ]] && [[ "$FROM_BRANCH" != *"fixbug"* ]] ; then

       #VERSION_TO_DEPLOY=${FIRSTLINE[6]}
       #echo "VERSION_TO_DEPLOY = $VERSION_TO_DEPLOY"
       #FROM_LINE=`grep "${CHANGED_DOC_NAME},${FROM_BRANCH_NAME}" ./document_schema_data.csv`
       #echo "FROM_LINE = $FROM_LINE"

       VERSION_TO_DEPLOY=${FROM_BRANCH_NAME#*/v}
       echo "VERSION_TO_DEPLOY = $VERSION_TO_DEPLOY"

       IFS='.' read -r -a from_data <<< "$VERSION_TO_DEPLOY"

       for i in "${!from_data[@]}"
       do
          echo "$i ${from_data[i]}"
          if (($i == 0)) ; then
             RELEASE_VERSION="${from_data[i]}"
             echo "RELEASE_VERSION = $RELEASE_VERSION"
          elif (($i == 1)) ; then
             DEPLOYMENT_VERSION="${from_data[i]}"
             echo "DEPLOYMENT_VERSION = $DEPLOYMENT_VERSION"
          elif (($i == 2)); then
             BUILD_VERSION="${from_data[i]}"
             echo "BUILD_VERSION = $BUILD_VERSION"
          fi;

       done

       while read line
       do
         echo "line = $line"
         IFS=',' read -r -a line_data <<< "$line"
         for i in "${!line_data[@]}"
         do
           echo "$i ${line_data[i]}"
           if (($i == 6)) ; then
              if [[ "${line_data[i]}" == "$DEPLOYMENT_VERSION" ]]; then
                current_deployment_version="${line_data[i]}"
                current_deployment_line="$line"
              fi;
           fi;
         done

       done <<< "$TO_LINE"
       
       NOT_DEPLOYED_BEFORE="false"

       if [ -z "$current_deployment_line" ]; then
        echo "version $VERSION_TO_DEPLOY not deployed to $TO_BRANCH previously ";
        TEMP_LINE_1=`sed -n 1p <<< "$TO_LINE"`
        current_deployment_line="$TEMP_LINE_1"
        NOT_DEPLOYED_BEFORE="true"
       fi;

    fi;
    #----------------------------------------------------------------------------------
    echo "current_deployment_version = $current_deployment_version"
    echo "current_deployment_line = $current_deployment_line"

    IFS=',' read -r -a data <<< "$current_deployment_line"

    for i in "${!data[@]}"
    do
       echo "$i ${data[i]}"
       if (($i == 5)) ; then   
          TAG_VERSION="${data[i]}."   
       fi;
       if (($i == 6)) ; then
     
         if [[ "$FROM_BRANCH" == *"feature"* ]]; then
           ((data[i]=data[i]+1));
           echo "$i after increment ${data[i]}";

         elif [[ "$FROM_BRANCH_NAME" == "release/"* ]] || [[ "$FROM_BRANCH_NAME" == "develop" ]] || [[ "$FROM_BRANCH_NAME" == "test" ]] || [[ "$FROM_BRANCH_NAME" == "sandbox" ]] || [[ "$FROM_BRANCH_NAME" == "demo" ]] ; then
           data[i]=$DEPLOYMENT_VERSION
         fi;
          TAG_VERSION="$TAG_VERSION${data[i]}."
       
       elif (($i == 7)); then

         if [[ "$FROM_BRANCH" == *"fixbug"* ]]; then
            ((data[i]=data[i]+1));
            echo "$i after increment ${data[i]}";

         elif [[ "$FROM_BRANCH" == *"feature"* ]]; then
           data[i]=0;
           echo "$i new feature with Build version ${data[i]}";
      
         elif [[ "$FROM_BRANCH_NAME" == "release/"* ]] || [[ "$FROM_BRANCH_NAME" == "develop" ]] || [[ "$FROM_BRANCH_NAME" == "test" ]] || [[ "$FROM_BRANCH_NAME" == "sandbox" ]] || [[ "$FROM_BRANCH_NAME" == "demo" ]] ; then
            data[i]=$BUILD_VERSION
         fi;
         TAG_VERSION="$TAG_VERSION${data[i]}";
       fi;

       if (($i == 0)) ; then
          NEWLINE="${data[i]}"
       elif (($i == 2)); then
          CURRENT_DATE=`date +'%Y-%m-%d %T'`
          echo "CURRENT_DATE = $CURRENT_DATE"
          NEWLINE="$NEWLINE,${CURRENT_DATE}"
       elif (($i == 4)); then
          echo "DEV_TL_VERSION = $TL_VERSION"
          NEWLINE="$NEWLINE,$TL_VERSION"
       else
          NEWLINE="$NEWLINE,${data[i]}"
       fi;
    done

    #------------------------------------------------

    echo "TO_LINE = $current_deployment_line"
    echo "FROM_LINE = $FROM_LINE"
    echo "NEWLINE = $NEWLINE"
    echo "TAG_VERSION = $TAG_VERSION"

    if [[ "$FROM_BRANCH" == *"fixbug"* ]]; then
    sed -i 's/'"$current_deployment_line"'/'"$NEWLINE"'/g' ./document_schema_data.csv

    elif [[ "$FROM_BRANCH" == *"feature"* ]]; then
      if [[ "$current_deployment_version" == 0 ]]; then  
       sed -i 's/'"$current_deployment_line"'/'"$NEWLINE"'/g' ./document_schema_data.csv
      else
        echo "$NEWLINE"  >> ./document_schema_data.csv
      fi; 

    elif [[ "$FROM_BRANCH_NAME" == "release/"* ]] ||[[ "$FROM_BRANCH_NAME" == "develop" ]] || [[ "$FROM_BRANCH_NAME" == "test" ]] || [[ "$FROM_BRANCH_NAME" == "sandbox" ]] || [[ "$FROM_BRANCH_NAME" == "demo" ]] ; then
       if [[ "$NOT_DEPLOYED_BEFORE" == "false" ]]; then
         sed -i 's/'"$current_deployment_line"'/'"$NEWLINE"'/g' ./document_schema_data.csv
       else
         echo "$NEWLINE"  >> ./document_schema_data.csv
       fi;
    fi;

    #sort -n -k1 ./document_schema_data.csv
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
    git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"$TO_BRANCH"
    if [[ "$FROM_BRANCH_NAME" == "release/"* ]]; then
      git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"$FROM_BRANCH_NAME"
    fi;

    if [[ "$TO_BRANCH" != "develop" ]]; then
        git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git HEAD:"develop"
    fi;

    if [[ "$TO_BRANCH" == "develop" ]]; then

       COMMIT_ID=`git rev-parse HEAD`
       echo "COMMIT_ID = $COMMIT_ID"
       git checkout -b release/$CHANGED_DOC_NAME/"v$TAG_VERSION" $COMMIT_ID
       git push https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git
       git tag -a "v$TAG_VERSION"'-'"$CHANGED_DOC_NAME" $COMMIT_ID -m "${TO_BRANCH} $CHANGED_DOC_NAME v$TAG_VERSION"
       git push --tags https://Eman-Github:$GITHUB_ACCESS_TOKEN@github.com/Eman-Github/Document-Schema-Deployment.git

    fi;
fi;
