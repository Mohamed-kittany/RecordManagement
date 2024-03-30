#!/bin/bash
# Author: Mohamed Kittany
# ¯\_(ツ)_/¯


### CLI Colors ###
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
ORANGE='\033[38;5;208m'
NO_COLOR='\033[0m'


# Check for filename argument, If the argument is invalid stop the script.
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Error: You must provide a filename as an argument.${NO_COLOR}"
    exit 1
fi


########################################################################################################################
################################################### Global Variables ###################################################
########################################################################################################################
FILENAME="$1"
LOGFILE="${FILENAME}_log"
# Holds the name of the currently selected or matched record.
CHOSEN_RECORD_NAME=""
# Stores the amount or value associated with the chosen record.
CHOSEN_RECORD_AMOUNT=""
# Indicates a specific condition's status (e.g., validation passed or failed).
CHECK_FLAG=0
# Flags if exactly one unique record match has been found (initially assumes no match).
ONE_RECORD_MATCH=1
########################################################################################################################


# logEvent -----------------------------------------------------------#
# Inputs: $1 = Event name, $2 = Success or Failure, $3 = Additional details (optional)
# Outputs: Logs the event details with a timestamp into the log file.
logEvent() {
    # $1 = Event name, $2 = Success or Failure, $3 = Additional details (optional)
    local eventName="$1"
    local eventOutcome="$2"
    local additionalDetails="$3"
    
    if [[ -n "$additionalDetails" ]]; then
        echo "$(date +'%d/%m/%Y %H:%M:%S') - $eventName $eventOutcome $additionalDetails" >> "$LOGFILE"
    else
        echo "$(date +'%d/%m/%Y %H:%M:%S') - $eventName $eventOutcome" >> "$LOGFILE"
    fi
}


########################################################################################################################
################################################## Validation section ##################################################
########################################################################################################################


# Check and create the record and log files if they do not exist.
if [ ! -f "$FILENAME" ]; then
    touch "$FILENAME"
    logEvent "Initialization" "Success" "Created record file: $FILENAME"
fi

if [ ! -f "$LOGFILE" ]; then
    touch "$LOGFILE"
    logEvent "Initialization" "Success" "Created log file: $LOGFILE"
fi


# validateRecordName -------------------------------------------------#
# Input: $1 = Record name (string)
# Output: Validates if the input is non-empty, alphanumeric, and doesn't start with a number.
# Returns 0 for valid names, 1 for invalid names.
validateRecordName() {
    if [[ -z "$1" || ! "$1" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
        echo -e "${RED}Invalid record name. Please use a non-empty string that doesn't start with a number.${NO_COLOR}"
        logEvent "Validation" "Failure" "Invalid record name attempted with '$1'"
        return 1
    fi
    return 0
}


# validateRecordAmount -----------------------------------------------#
# Input: $1 = Amount (string)
# Output: Checks if the input is a positive integer.
# Returns 0 for valid amounts, 1 for invalid amounts.
validateRecordAmount() {
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid amount. Please enter a positive integer.${NO_COLOR}"
        logEvent "Invalid amount" "Attempted with '$1'"
        return 1
    fi
    return 0
}


########################################################################################################################
############################################### Manage Record Operations ###############################################
########################################################################################################################


#printAllSortedRecords -----------------------------------------------#
# Input: None
# Output: Lists all records in sorted order by name.
printAllSortedRecords() {
    # Check if the file is not empty
    if [ -s "$FILENAME" ]; then
        echo -e "${BLUE}All records sorted:${NO_COLOR}"
        sort "$FILENAME"
        logEvent "Print All Sorted" "Success" "Displayed all records sorted"
    else
        echo -e "${RED}The file is empty. No records to sort.${NO_COLOR}"
        logEvent "Print All Sorted" "Failure" "File is empty"
    fi
}


# printRecordsTotalAmount ---------------------------------------------------#
# Input: None
# Output: Displays the total sum of amounts from all records.
printRecodsTotalAmount() {
    # Check if the file is not empty
    if [ -s "$FILENAME" ]; then
        local total=0
        while IFS=, read -r name amount; do
            let total+=amount
        done < "$FILENAME"

        echo -e "${BLUE}Total amount of records: ${total}.${NO_COLOR}"
        logEvent "Print Total Amount" "Success" "Displayed total amount: $total"
    else
        echo -e "${RED}The file is empty. No total amount to display.${NO_COLOR}"
        logEvent "Print Total Amount" "Failure" "File is empty"
    fi
}


#searchRecord -------------------------------------------------------#
# Input: $1 = Keyword (string) to search within record names. If not passed, prompts the user.
# Output: Displays all records matching the search keyword.
# Note: Returns 0 if a match is found, 1 otherwise.
searchRecord() {
    local keyWord
    # Check if keyword argument was passed. <-- From the Manage Record Operations.
    if (( $# == 1 )); then
        keyWord=$1
    else 
        read -p "Enter a keyword: " keyWord
        validateRecordName "$keyWord" || return
        echo -e "${BLUE}Search results:${NO_COLOR}"
    fi

    # Search by keyword & adding line numbers to the results
    local results=$(grep -n "$keyWord" "$FILENAME")
    local lineCount=$(echo "$results" | wc -l)
    CHOSEN_RECORD_NAME=""
    CHOSEN_RECORD_AMOUNT=""
    CHECK_FLAG=0
    ONE_RECORD_MATCH=1

    # Check if any results were found
    if [[ -z "$results" ]]; then
        if (( $# == 0 )); then
            echo -e "${RED}No records found.${NO_COLOR}"
        fi
        logEvent "Search Record" "Failure" "No records found for '$keyWord'"
        return 1
    else
        if [ "$lineCount" -eq 1 ]; then
            CHOSEN_RECORD_NAME=$(echo "$results" | cut -d: -f2 | cut -d, -f1)
            CHOSEN_RECORD_AMOUNT=$(echo "$results" | cut -d: -f2 | cut -d, -f2)
            # Here we check if the given keyword match exactly the existing record.
            ONE_RECORD_MATCH=0 
            logEvent "Search Record" "Success" "One match found for '$keyWord'"
            return 0
        else
            # Print matching records
            local lineNumber=1  
            echo "$results" | while IFS= read -r line; do
            echo "${lineNumber}) ${line#*:}"
                ((lineNumber++))  
            done

            # This section is used for the rest of manage record operation only. (letting the user decide which record to perform a specific action)
            if (( $# == 1 )); then 
                read -p "Enter the number of the record you want to perform the action: " choice
                # Validate the user's choice
                if (( choice > 0 && choice <= lineCount )); then
                    local selectedRecord=$(echo "$results" | sed -n "${choice}p")
                    CHOSEN_RECORD_NAME=$(echo "$selectedRecord" | cut -d: -f2 | cut -d, -f1)
                    CHOSEN_RECORD_AMOUNT=$(echo "$selectedRecord" | cut -d: -f2 | cut -d, -f2)
                    logEvent "Search Record" "Success" "User selected record $choice for keyword '$keyWord'"
                    return 0
                else
                    echo -e "${RED}Invalid selection.${NO_COLOR}"
                    logEvent "Search Record" "Failure" "User made an invalid selection for '$keyWord'"
                    # Since the functon has two return value = 1, here we differentiate the second return value from the first with this flag variable.
                    CHECK_FLAG=1
                    return 1
                fi
            fi

            logEvent "Search Record" "Success" "User selected record for keyword '$keyWord'"
            return 0
        fi
    fi
}


#updateRecordName ---------------------------------------------------#
# Input: $1 = Current record name (string), $2 = New record name (string). If not passed, prompts the user.
# Output: Changes the name of an existing record to a new name.
updateRecordName() {
    local currentName=""
    local newRecordName=""

    # Check if arguments were passed from the Manage Record Operations.
    if (( $# == 2 )); then
        currentName="$1"
        newRecordName="$2"
    else 
        echo -e "${BLUE}Update Record Name Operation:${NO_COLOR}"

        read -p "Enter current record name: " currentName
        validateRecordName "$currentName" || return
        read -p "Enter new record name: " newRecordName
        validateRecordName "$newRecordName" || return
    fi
    
    # Directly call searchRecord to maintain terminal output and user interaction without
    # creating a sub-shell, preserving immediate side-effects in the current shell context.
    searchRecord "$currentName"

    # Exit result = 0 (success) | 1 (failure)
    local searchExitResult=$?

    if (( searchExitResult == 0 )); then
        sed -i "s/^${CHOSEN_RECORD_NAME},/${newRecordName},/" "$FILENAME"
        echo -e "${GREEN}Record name updated successfully from '${CHOSEN_RECORD_NAME}' to '${newRecordName}'.${NO_COLOR}"
        logEvent "Update Record Name" "Success" "From '${currentName}' to '${newRecordName}'"
    else
        echo -e "${RED}No matches found for the specified record name ${currentName}${NO_COLOR}"
        logEvent "Update Record Name" "Failure" "Update process encountered an issue for '${currentName}'"
    fi
}


#updateRecordAmount -------------------------------------------------#
# Input: $1 = Record name (string), $2 = New amount (integer), $3 = Check if we need to
# run the searchRecord function.
# If nothing passed, prompts the user.
# Output: Updates the amount for the specified record.
updateRecordAmount() {
    local recordName=""
    local newRecordAmount=""
    local runSearchRecord="0"
    # Check if arguments were passed from the Manage Record Operations.
    if (( $# > 0 )); then
        recordName="$1"
        newRecordAmount="$2"
        runSearchRecord="$3"
    else 
        echo -e "${BLUE}Update record amount operation:${NO_COLOR}"

        read -p "Enter record name: " recordName
        validateRecordName "$recordName" || return
        read -p "Enter new record amount: " newRecordAmount
    fi
    validateRecordAmount "$newRecordAmount" || return

    if [ $newRecordAmount -lt 1 ]; then
        echo -e "${RED}Record amount Cannot be less than 1.${NO_COLOR}"
        logEvent "Update Record Amount" "Failure" "Given amount less than 1"
        return
    fi
    local searchExitResult=0
    if [[ "$runSearchRecord" == "0" ]]; then
        # Directly call searchRecord to maintain terminal output and user interaction without
        # creating a sub-shell, preserving immediate side-effects in the current shell context.
        searchRecord "$recordName"

        # Exit result = 0 (success) | 1 (failure)
        searchExitResult=$?
    fi


    if (( searchExitResult == 0 )); then
        # Replacing the whole line (record,amount) with the new amount using sed to find the record by its name
    sed -i "s/^${CHOSEN_RECORD_NAME},.*/${CHOSEN_RECORD_NAME},${newRecordAmount}/" "$FILENAME"

    echo -e "${GREEN}Record amount updated successfully.${NO_COLOR}"
    logEvent "Update Record Amount" "Success" "Updated amount for '${recordName}'"
    else
        if [[ $runSearchRecord == "0" ]]; then
            echo -e "${RED}No matches found for the specified record name ${recordName}${NO_COLOR}"
            logEvent "Update Record Amount" "Failure" "No matches found for '${recordName}'"
        fi
    fi
}


#addRecord ----------------------------------------------------------#
# Input: None (prompts user for Record name and Amount)
# Output: Adds a new record to the file if it doesn't already exist.
addRecord() {
    local recordName=""
    local recordAmount=""

    echo -e "${BLUE}Add record operation:${NO_COLOR}"
    read -p "Enter record name: " recordName
    validateRecordName "$recordName" || return
    
    read -p "Enter new record amount: " recordAmount
    validateRecordAmount "$recordAmount" || return

    # Call the searchRecord function to search for the entered recordName.
    searchRecord "$recordName"
    local searchResult=$? # Capture the return status of searchRecord (0 | 1)
    
    if (( "$searchResult" == 1 )); then
        if (( CHECK_FLAG == 0 )); then
            echo "${recordName},${recordAmount}" >> "$FILENAME"
            logEvent "Add Record" "New record added: '$recordName' with amount '$recordAmount'"
            echo -e "${GREEN}Record added successfully.${NO_COLOR}"
        fi
    else
        if [[ "$ONE_RECORD_MATCH" == "0" ]]; then
            if [[ "$CHOSEN_RECORD_NAME" == "$recordName" ]]; then
                sumAmount=$((recordAmount + CHOSEN_RECORD_AMOUNT))
                updateRecordAmount "$CHOSEN_RECORD_NAME" "$sumAmount" "1"
            else
                echo -e "Found one record named: ${YELLOW}$CHOSEN_RECORD_NAME${NO_COLOR}. Do you want to update its amount or create a new record?"
                echo "1) Update Existing record amount"
                echo "2) Create new record"
                read choice
                case $choice in
                    1) 
                        sumAmount=$((recordAmount + CHOSEN_RECORD_AMOUNT))
                        updateRecordAmount "$recordName" "$sumAmount" "1"
                        ;;
                    2) 
                        echo "${recordName},${recordAmount}" >> "$FILENAME"
                        echo -e "${GREEN}Record added successfully.${NO_COLOR}"
                        logEvent "Add Record" "New record added: '$recordName' with amount '$recordAmount'"
                        ;;
                    *) 
                    echo -e "${RED}Invalid option, please try again.${NO_COLOR}"
                    return
                    ;;
                esac
            fi
            return
        else
            sumAmount=$((recordAmount + CHOSEN_RECORD_AMOUNT))
            updateRecordAmount "$recordName" "$sumAmount" "1"
        fi
    fi
}


#deleteRecord -------------------------------------------------------#
# Input: None (prompts user for Record name to be deleted)
# Output: Removes the specified record from the file.
#---------------------------------------------------------------------#
deleteRecord() {
    local recordName=""
    local amountToDelete=""

    echo -e "${BLUE}Delete record operation:${NO_COLOR}"
    read -p "Enter record name: " recordName
    validateRecordName "$recordName" || return
    
    read -p "Enter amount to delete from the record: " amountToDelete
    validateRecordAmount "$amountToDelete" || return

    # Call the searchRecord function to search for the entered recordName.
    searchRecord "$recordName"
    local searchResult=$? # Capture the return status of searchRecord (0 | 1)

    if (( searchResult == 1 )); then
        if (( CHECK_FLAG == 0 )); then
            echo -e "${RED}Error: Record not found.${NO_COLOR}"
            logEvent "Delete Record" "Failure" "Record not found"
        fi
        return 
    fi

    if (( CHOSEN_RECORD_AMOUNT < amountToDelete )); then
        echo -e "${RED}Error: Amount to delete exceeds the available amount.${NO_COLOR}"
        logEvent "Delete Record" "Failure" "Excess amount"
        return 
    fi

    # Update or delete the record based on the remaining amount
    local newAmount=$((CHOSEN_RECORD_AMOUNT - amountToDelete))
    if (( newAmount > 0 )); then
        # Update the record with the new amount
        updateRecordAmount "$CHOSEN_RECORD_NAME" "$newAmount" "1"
        echo -e "${GREEN}Record updated successfully.${NO_COLOR}"
        logEvent "Delete Record" "Success" "Record updated"
    else
        # Delete the record entirely
        sed -i "/^${CHOSEN_RECORD_NAME},/d" "$FILENAME"
        echo -e "${GREEN}Record deleted successfully.${NO_COLOR}"
        logEvent "Delete Record" "Success" "Record deleted"
    fi
}


#exitScript()---------------------------------------------------------#
#input: None
#output: Logs the exit action and terminates the script
#---------------------------------------------------------------------#
exitScript() {
    echo -e "${GREEN}Exiting the script. Goodbye!${NO_COLOR}"
    logEvent "Exit" "Success" "Script exited successfully"
    exit 0
}


########################################################################################################################
######################################################### Menu #########################################################
########################################################################################################################

# Function to print menu options with the number in orange
printOption() {
    echo -e "${ORANGE}$1.${NO_COLOR} $2"
}


# Function to display the menu options
displayMenu() {
    echo -e "\n${YELLOW}¯\_(ツ)_/¯ ${BLUE}Record Management System ${YELLOW}¯\_(ツ)_/¯${NO_COLOR}"
    printOption "1" "Add a Record"
    printOption "2" "Delete a Record"
    printOption "3" "Search for a Record"
    printOption "4" "Update a Record's Name"
    printOption "5" "Update a Record's Amount"
    printOption "6" "Print Total Amount of Records"
    printOption "7" "Print All Records Sorted"
    printOption "8" "Exit"
    echo -e "${YELLOW}Enter your choice: ${NO_COLOR}"
}


########################################################################################################################
######################################################## Main ##########################################################
########################################################################################################################

main() {
    while true; do
        displayMenu
        read choice
        case $choice in
            1) addRecord ;;
            2) deleteRecord ;;
            3) searchRecord ;;
            4) updateRecordName ;;
            5) updateRecordAmount ;;
            6) printRecodsTotalAmount ;;
            7) printAllSortedRecords ;;
            8) exitScript ;;
            *) echo -e "${RED}Invalid option, please try again.${NO_COLOR}" ;;
        esac
    done
}


main
