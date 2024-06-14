#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NAVIGATION="${DIR}/../MapboxNavigation"
CORE="${DIR}/../MapboxCoreNavigation"

LANGUAGES=( "Base" )

for lang in ${LANGUAGES[@]}
do
    source "${DIR}/file_conversion.sh"

    echo "Extracting ${lang} strings"

    # Extract localizable strings from .swift files
    find ${NAVIGATION} -name "*.swift" -print0 | xargs -0 xcrun extractLocStrings -o "${NAVIGATION}/Resources/${lang}.lproj"
    STRINGS_FILE="${NAVIGATION}/Resources/${lang}.lproj/Localizable.strings"
    convertIfNeeded "$STRINGS_FILE"

    # Extract localizable strings from .swift files
    find ${CORE} -name "*.swift" -print0 | xargs -0 xcrun extractLocStrings -o "${CORE}/Resources/${lang}.lproj"
    STRINGS_FILE="${CORE}/Resources/${lang}.lproj/Localizable.strings"
    convertIfNeeded "$STRINGS_FILE"
done
