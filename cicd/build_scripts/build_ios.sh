# convo ai cn cicd
export LANG=en_US.UTF-8

export PATH=$PATH:/opt/homebrew/bin

# Set global variables
if [ -z "$WORKSPACE" ]; then
    export WORKSPACE=$(pwd)/cicd/iosExport
    export LOCALPACKAGE="true"
    mkdir -p $WORKSPACE
fi

if [ -z "$build_date" ]; then
    export build_date=$(date +%Y%m%d)
fi

if [ -z "$build_time" ]; then
    export build_time=$(date +%H%M%S)
fi

BUILD_VERSION=$(date +%Y%m%d%H%M%S)
CURRENT_PATH=$PWD
# Project target name
PROJECT_NAME=Agent
TARGET_NAME=Agent-cn

# Get project directory
PROJECT_PATH="${CURRENT_PATH}/iOS"
if [ ! -d "${PROJECT_PATH}" ]; then
    echo "Error: iOS directory not found: ${PROJECT_PATH}"
    echo "Build failed: iOS project directory does not exist"
    exit 1
fi

if [ -z "$toolbox_url" ]; then
    export toolbox_url="https://service.apprtc.cn/toolbox"
fi

if [[ "${toolbox_url}" != *"https://"* ]]; then
    toolbox_url="https://${toolbox_url}"
fi

# Select corresponding APP_ID based on toolbox_url keywords
if [[ "${toolbox_url}" == *"dev"* ]]; then
    echo "Using development environment APP_ID (dev)"
    if [ -n "$APP_ID_DEV" ]; then
        APP_ID=${APP_ID_DEV}
    else
        echo "Warning: APP_ID_DEV environment variable not set"
    fi
elif [[ "${toolbox_url}" == *"staging"* ]]; then
    echo "Using staging environment APP_ID (staging)"
    if [ -n "$APP_ID_STAGING" ]; then
        APP_ID=${APP_ID_STAGING}
    else
        echo "Warning: APP_ID_STAGING environment variable not set"
    fi
else
    echo "Using production environment APP_ID (prod)"
    if [ -n "$APP_ID_PROD" ]; then
        APP_ID=${APP_ID_PROD}
    else
        echo "Warning: APP_ID_PROD environment variable not set"
    fi
fi

if [ -z "$APP_ID" ]; then
    echo "Warning: All APP_ID environment variables are not set, using default empty value"
    APP_ID=""
fi

if [ "$upload_app_store" = "true" ]; then
    export method="app-store"
    echo "Setting export method to: app-store (app-store package)"
else
    export method="development"
    echo "Setting export method to: development (test package)"
fi

if [ -z "$bundle_id" ]; then
    export bundle_id="cn.shengwang.convoai"
fi

echo Package_Publish: $Package_Publish
echo is_tag_fetch: $is_tag_fetch
echo arch: $arch
echo source_root: %source_root%
echo output: /tmp/jenkins/${project}_out
echo build_date: $build_date
echo build_time: $build_time
echo pwd: `pwd`
echo sdk_url: $sdk_url
echo toolbox_url: $toolbox_url
echo "APP_ID: ${APP_ID}"
echo "bundle_id: ${bundle_id}"
# Check key environment variables
echo "Checking iOS build environment variables:"
echo "Xcode version: $(xcodebuild -version | head -n 1)"
echo "Swift version: $(swift --version | head -n 1)"
echo "Ruby version: $(ruby --version)"
echo "CocoaPods version: $(pod --version)"

echo PROJECT_PATH: $PROJECT_PATH
echo TARGET_NAME: $TARGET_NAME
echo pwd: $CURRENT_PATH

# Download environment configuration file
echo "Starting to download environment configuration file..."
ASSETS_DIR="${PROJECT_PATH}/Common/Common/Assets"
mkdir -p "${ASSETS_DIR}"

# Ensure dev_env_config_url contains https:// prefix
if [[ ! -z ${dev_env_config_url} ]]; then
    if [[ "${dev_env_config_url}" != *"https://"* ]]; then
        # If URL doesn't contain https:// prefix, add it
        dev_env_config_url="https://${dev_env_config_url}"
        echo "Adding https prefix to config file URL: ${dev_env_config_url}"
    fi

    echo "Downloading environment config file: ${dev_env_config_url}"
    curl -L -v -H "X-JFrog-Art-Api:${JFROG_API_KEY}" -o "${ASSETS_DIR}/dev_env_config.json" "${dev_env_config_url}" || exit 1
    echo "Environment config file downloaded, saved to ${ASSETS_DIR}/dev_env_config.json"
else
    echo "dev_env_config_url not specified, skipping environment config file download"
fi

PODFILE_PATH=${PWD}"/iOS/Podfile"

if [[ ! -z ${sdk_url} && "${sdk_url}" != 'none' ]]; then
    zip_name=${sdk_url##*/}
    curl -L -v -H "X-JFrog-Art-Api:${JFROG_API_KEY}" -O $sdk_url || exit 1
    unzip -o ./$zip_name -y

    unzip_name=`ls -S -d */ | grep Agora`
    echo unzip_name: $unzip_name

    mv "${PWD}/${unzip_name}/libs" "${PWD}/iOS"

    # Modify podfile
    sed -i '' "s#pod 'AgoraRtcEngine.*#pod 'sdk', :path => 'sdk.podspec'#g" ${PODFILE_PATH}
fi

cd ${PROJECT_PATH}
#pod install --repo-update
pod update --no-repo-update

if [ $? -eq 0 ]; then
    echo "success"
else
    echo "failed"
    exit 1
fi

# Read version number from project configuration
export release_version=$(xcodebuild -workspace "${PROJECT_PATH}/${PROJECT_NAME}.xcworkspace" -scheme "${TARGET_NAME}" -showBuildSettings | grep "MARKETING_VERSION" | cut -d "=" -f 2 | tr -d " ")
if [ -z "$release_version" ]; then
    echo "Error: Unable to read version number from project configuration"
    exit 1
fi
echo "Version number read from project configuration: ${release_version}"

# Artifact name
export ARTIFACT_NAME="ShengWang_Conversational_Al_Engine_Demo_for_iOS_v${release_version}_${BUILD_VERSION}"

KEYCENTER_PATH=${PROJECT_PATH}"/"${PROJECT_NAME}"/KeyCenter.swift"

# Build environment
CONFIGURATION='Release'

# Signing configuration
if [[ "$bundle_id" == *"test"* ]]; then
    PROVISIONING_PROFILE="shengwang_convoai_test"
    CODE_SIGN_IDENTITY="iPhone Distribution"
    DEVELOPMENT_TEAM="48TB6ZZL5S"
    PLIST_PATH="${CURRENT_PATH}/cicd/build_scripts/ios_export_store_test.plist"
else
    PROVISIONING_PROFILE="shengwang_convoai_appstore"
    CODE_SIGN_IDENTITY="iPhone Distribution"
    DEVELOPMENT_TEAM="48TB6ZZL5S"
    PLIST_PATH="${CURRENT_PATH}/cicd/build_scripts/ios_export_store_prod.plist"
fi

# Project file path
APP_PATH="${PROJECT_PATH}/${PROJECT_NAME}.xcworkspace"

# Project configuration path
PBXPROJ_PATH="${PROJECT_PATH}/${PROJECT_NAME}.xcodeproj/project.pbxproj"
echo PBXPROJ_PATH: $PBXPROJ_PATH

# Verify file existence
echo "Verifying file and directory existence:"
if [ ! -e "${APP_PATH}" ]; then
    echo "Error: Project file not found: ${APP_PATH}"
    # Search for workspace files
    find ${PROJECT_PATH} -name "*.xcworkspace"
    exit 1
fi

if [ ! -f "${PBXPROJ_PATH}" ]; then
    echo "Error: Project configuration file not found: ${PBXPROJ_PATH}"
    # Search for project.pbxproj files
    find ${PROJECT_PATH} -name "project.pbxproj" -type f
    exit 1
fi

security unlock-keychain -p "123456" ~/Library/Keychains/login.keychain
# Main project configuration
# Debug
sed -i '' "s|CURRENT_PROJECT_VERSION = .*;|CURRENT_PROJECT_VERSION = ${BUILD_VERSION};|g" $PBXPROJ_PATH
sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = .*;|PRODUCT_BUNDLE_IDENTIFIER = \"${bundle_id}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_STYLE = .*;|CODE_SIGN_STYLE = \"Manual\";|g" $PBXPROJ_PATH
sed -i '' "s|DEVELOPMENT_TEAM = .*;|DEVELOPMENT_TEAM = \"${DEVELOPMENT_TEAM}\";|g" $PBXPROJ_PATH
sed -i '' "s|PROVISIONING_PROFILE_SPECIFIER = .*;|PROVISIONING_PROFILE_SPECIFIER = \"${PROVISIONING_PROFILE}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_IDENTITY = .*;|CODE_SIGN_IDENTITY = \"${CODE_SIGN_IDENTITY}\";|g" $PBXPROJ_PATH

# Release
sed -i '' "s|CURRENT_PROJECT_VERSION = .*;|CURRENT_PROJECT_VERSION = ${BUILD_VERSION};|g" $PBXPROJ_PATH
sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = .*;|PRODUCT_BUNDLE_IDENTIFIER = \"${bundle_id}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_STYLE = .*;|CODE_SIGN_STYLE = \"Manual\";|g" $PBXPROJ_PATH
sed -i '' "s|DEVELOPMENT_TEAM = .*;|DEVELOPMENT_TEAM = \"${DEVELOPMENT_TEAM}\";|g" $PBXPROJ_PATH
sed -i '' "s|PROVISIONING_PROFILE_SPECIFIER = .*;|PROVISIONING_PROFILE_SPECIFIER = \"${PROVISIONING_PROFILE}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_IDENTITY = .*;|CODE_SIGN_IDENTITY = \"${CODE_SIGN_IDENTITY}\";|g" $PBXPROJ_PATH

# Read APPID environment variable
echo AGORA_APP_ID:$APP_ID

echo PROJECT_PATH: $PROJECT_PATH
echo PROJECT_NAME: $PROJECT_NAME
echo TARGET_NAME: $TARGET_NAME
echo KEYCENTER_PATH: $KEYCENTER_PATH
echo APP_PATH: $APP_PATH
echo PLIST_PATH: $PLIST_PATH

# Modify Keycenter file
# Use sed to replace parameters in KeyCenter.swift
if [ -n "$APP_ID" ]; then
    sed -i '' "s|static let AG_APP_ID: String = .*|static let AG_APP_ID: String = \"$APP_ID\"|g" $KEYCENTER_PATH
fi
if [ -n "$toolbox_url" ]; then
    sed -i '' "s|static let TOOLBOX_SERVER_HOST: String = .*|static let TOOLBOX_SERVER_HOST: String = \"$toolbox_url\"|g" $KEYCENTER_PATH
fi

# Modify IS_OPEN_SOURCE to false
sed -i '' "s|static var IS_OPEN_SOURCE: Bool = .*|static var IS_OPEN_SOURCE: Bool = false|g" $KEYCENTER_PATH
echo "Check modification results："
grep "static var IS_OPEN_SOURCE" $KEYCENTER_PATH

# Archive path
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_VERSION}.xcarchive"

# Build and archive
echo "Starting build and archive..."
xcodebuild clean -workspace "${APP_PATH}" -scheme "${TARGET_NAME}" -configuration "${CONFIGURATION}" -quiet
xcodebuild CODE_SIGN_STYLE="Manual" \
    -workspace "${APP_PATH}" \
    -scheme "${TARGET_NAME}" \
    clean \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -configuration "${CONFIGURATION}" \
    archive \
    -archivePath "${ARCHIVE_PATH}" \
    -destination 'generic/platform=iOS' \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    -quiet || exit

# Create export directory
EXPORT_PATH="${WORKSPACE}/output"
# Clean existing export directory
if [ -d "${EXPORT_PATH}" ]; then
    echo "Cleaning existing export directory: ${EXPORT_PATH}"
    rm -rf "${EXPORT_PATH}"
fi
mkdir -p "${EXPORT_PATH}"

# Export IPA
echo "Starting IPA export..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${PLIST_PATH}" \
    -allowProvisioningUpdates

cd ${WORKSPACE}

# Create temporary directory for packaging files
PACKAGE_DIR="${WORKSPACE}/package_temp"
mkdir -p "${PACKAGE_DIR}"

# Copy IPA and dSYM to temporary directory
if [ -f "${EXPORT_PATH}/${TARGET_NAME}.ipa" ]; then
    cp "${EXPORT_PATH}/${TARGET_NAME}.ipa" "${PACKAGE_DIR}/${ARTIFACT_NAME}.ipa"
else
    echo "Error: IPA file not found!"
    exit 1
fi

# upload ipa to appstore
if [ "$LOCALPACKAGE" != "true" ]; then
    if [ "$upload_app_store" = "true" ]; then
        echo "Uploading IPA to App Store..."
        UPLOAD_RESULT=$(xcrun altool --upload-app \
            -f "${PACKAGE_DIR}/${ARTIFACT_NAME}.ipa" \
            -u "${IOS_APPSTORE_USER}" \
            -p "${IOS_APPSTORE_PASSW}" \
            -t ios 2>&1)
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to upload IPA to App Store"
            echo "Upload error details:"
            echo "$UPLOAD_RESULT"
            exit 1
        fi
        echo "Successfully uploaded IPA to App Store"
        echo "Upload details:"
        echo "$UPLOAD_RESULT"
    else
        echo "Skipping App Store upload as upload_app_store is not set to true"
    fi
fi

if [ -d "${ARCHIVE_PATH}/dSYMs" ] && [ "$(ls -A "${ARCHIVE_PATH}/dSYMs")" ]; then
    cp -r "${ARCHIVE_PATH}/dSYMs" "${PACKAGE_DIR}/"
else
    echo "Warning: dSYMs directory is empty or does not exist!"
    mkdir -p "${PACKAGE_DIR}/dSYMs"
fi

# Package IPA and dSYM
cd "${PACKAGE_DIR}"
zip -r "${WORKSPACE}/${ARTIFACT_NAME}.zip" ./
cd "${WORKSPACE}"

# Upload file and delete local zip for non-local builds
if [ "$LOCALPACKAGE" != "true" ]; then
    echo "Uploading artifact to artifact repository..."
    
    # Upload file to artifact repository and save output
    UPLOAD_RESULT=$(python3 artifactory_utils.py --action=upload_file --file="${ARTIFACT_NAME}.zip" --project)
    
    # Check if upload result is a URL
    if [[ "$UPLOAD_RESULT" =~ ^https?:// ]]; then
        echo "====🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉========="
        echo "Artifact uploaded successfully! Download URL:"
        echo "$UPLOAD_RESULT"
        echo "===================================================="
    else
        echo "Warning: Upload result format is abnormal"
        echo "Complete upload result:"
        echo "$UPLOAD_RESULT"
    fi
    
    # Clean up local artifact
    rm -f "${ARTIFACT_NAME}.zip"
fi

# Clean up files
rm -rf ${TARGET_NAME}_${BUILD_VERSION}.xcarchive
rm -rf ${PACKAGE_DIR}
rm -rf ${EXPORT_PATH}

echo 'Build completed'