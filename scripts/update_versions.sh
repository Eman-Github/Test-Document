#!/bin/bash
set -ev

echo "Changed file = $1";
echo "TradeLens Version = $2 ";

if [ -z $1 ]; then
    echo "CHANGED_FILES can't be null ";
    exit;
fi;

if [[ "$2" =~ ^[0-9]+$ ]]; then
   echo "TL version is a number"
else
   echo "TL Version is not right number";
   exit;
fi;

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
      echo "DEV_TL_VERSION = $2"
      NEWLINE="$NEWLINE,$2"
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
