#!/bin/bash
set -ev

if [[ -z $2 ]]; then
    echo "No Schema document changed"
    exit
fi

export CHANGED_FILE=$2

if [[ "$CHANGED_FILE" = *"BillOfLading"* ]]
then
  echo "BillOfLading document schema has been changed";
  export CHANGED_DOC_NAME="BillOfLading";
  echo $CHANGED_DOC_NAME;

elif [[ "$CHANGED_FILE" = *SeaWaybill* ]]
then
  echo "SeaWaybill document schema has been changed";
  export CHANGED_DOC_NAME="SeaWaybill";
  echo $CHANGED_DOC_NAME;

elif [[ "$CHANGED_FILE" = *VerifyCopy* ]]
then
  echo "VerifyCopy document schema has been changed";
  export CHANGED_DOC_NAME="VerifyCopy";
  echo $CHANGED_DOC_NAME;

elif [[ "$CHANGED_FILE" = *ShippingInstructions* ]]
then
  echo "ShippingInstructions document schema has been changed";
  export CHANGED_DOC_NAME="ShippingInstructions";
  echo $CHANGED_DOC_NAME;

elif [[ "$CHANGED_FILE" = *BookingRequest* ]]
then
  echo "ShippingInstructions document schema has been changed";
  export CHANGED_DOC_NAME="BookingRequest";
  echo $CHANGED_DOC_NAME;

fi;

