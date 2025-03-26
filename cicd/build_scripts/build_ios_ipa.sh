CURRENT_PATH=$PWD

swift_version=$(swift --version)
echo "Swift 版本: $swift_version"

xcode_version=$(xcodebuild -version)
echo "当前 Xcode 版本: $xcode_version"

# 获取项目目录
PROJECT_PATH="${CURRENT_PATH}/iOS"
# 项目target名
PROJECT_NAME=Agent
TARGET_NAME=Agent-cn

echo PROJECT_PATH: $PROJECT_PATH
echo TARGET_NAME: $TARGET_NAME
echo pwd: $CURRENT_PATH
echo pod_cache_url: $pod_cache_url

cd ${PROJECT_PATH}
if [[ $pod_cache_url == *https://* ]]; then
    echo pod cache found, pod install ignore!
else
    pod update --no-repo-update
fi

if [ $? -eq 0 ]; then
    echo "success"
else
    echo "failed"
    exit 1
fi

KEYCENTER_PATH=${PROJECT_PATH}"/"${PROJECT_NAME}"/KeyCenter.swift"

# 打包环境
CONFIGURATION='Release'
result=$(echo ${method} | grep "development")
if [[ ! -z "$result" ]]; then
    CONFIGURATION='Debug'
fi

#工程文件路径
APP_PATH="${PROJECT_PATH}/${PROJECT_NAME}.xcworkspace"

#工程配置路径
PBXPROJ_PATH="${PROJECT_PATH}/${PROJECT_NAME}.xcodeproj/project.pbxproj"
echo PBXPROJ_PATH: $PBXPROJ_PATH

# 主项目工程配置
# Debug
# /usr/libexec/PlistBuddy -c "Set :objects:DD2A43F228FFCEE7004CEDCF:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
# /usr/libexec/PlistBuddy -c "Set :objects:DD2A43F228FFCEE7004CEDCF:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
# /usr/libexec/PlistBuddy -c "Set :objects:DD2A43F228FFCEE7004CEDCF:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'App'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:DD2A43F228FFCEE7004CEDCF:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:DD2A43F228FFCEE7004CEDCF:buildSettings:PRODUCT_BUNDLE_IDENTIFIER ${bundleId}" $PBXPROJ_PATH
# Release
# /usr/libexec/PlistBuddy -c "Set :objects:DD2A43F328FFCEE7004CEDCF:buildSettings:CODE_SIGN_STYLE 'Manual'" $PBXPROJ_PATH
# /usr/libexec/PlistBuddy -c "Set :objects:DD2A43F328FFCEE7004CEDCF:buildSettings:DEVELOPMENT_TEAM 'YS397FG5PA'" $PBXPROJ_PATH
# /usr/libexec/PlistBuddy -c "Set :objects:DD2A43F328FFCEE7004CEDCF:buildSettings:PROVISIONING_PROFILE_SPECIFIER 'App'" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:DD2A43F328FFCEE7004CEDCF:buildSettings:CURRENT_PROJECT_VERSION ${BUILD_NUMBER}" $PBXPROJ_PATH
/usr/libexec/PlistBuddy -c "Set :objects:DD2A43F328FFCEE7004CEDCF:buildSettings:PRODUCT_BUNDLE_IDENTIFIER ${bundleId}" $PBXPROJ_PATH

# 读取APPID环境变量
echo AGORA_APP_ID:$APP_ID
echo $AGORA_APP_ID

echo PROJECT_PATH: $PROJECT_PATH
echo PROJECT_NAME: $PROJECT_NAME
echo TARGET_NAME: $TARGET_NAME
echo KEYCENTER_PATH: $KEYCENTER_PATH
echo APP_PATH: $APP_PATH
echo manifest_url: $manifest_url

#修改Keycenter文件
python3 ./cicd/build_scripts/modify_ios_keycenter.py $KEYCENTER_PATH 0 $manifest_url

# Xcode clean
xcodebuild clean -workspace "${APP_PATH}" -configuration "${CONFIGURATION}" -scheme "${TARGET_NAME}" -quiet

# 时间戳
CURRENT_TIME=$(date "+%Y-%m-%d_%H-%M-%S")

# 归档路径
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive" #"${PROJECT_PATH}/${TARGET_NAME}_${CURRENT_TIME}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive"
# 编译环境

# plist路径
PLIST_PATH="${CURRENT_PATH}/cicd/build_scripts/ExportOptions_${method}.plist"

echo PLIST_PATH: $PLIST_PATH

xcodebuild CODE_SIGN_STYLE="Manual" -workspace "${APP_PATH}" -scheme "${TARGET_NAME}" clean CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -configuration "${CONFIGURATION}" archive -archivePath "${ARCHIVE_PATH}" -destination 'generic/platform=iOS' DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -quiet || exit

# 创建导出目录
EXPORT_PATH="${WORKSPACE}/export"
mkdir -p "${EXPORT_PATH}"

# 导出IPA
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${PLIST_PATH}" \
    -allowProvisioningUpdates

cd ${WORKSPACE}

# 创建临时目录用于存放待打包文件
PACKAGE_DIR="${WORKSPACE}/package_temp"
mkdir -p "${PACKAGE_DIR}"

# 复制IPA和dSYM到临时目录
if [ -f "${EXPORT_PATH}/${TARGET_NAME}.ipa" ]; then
    cp "${EXPORT_PATH}/${TARGET_NAME}.ipa" "${PACKAGE_DIR}/"
else
    echo "错误: IPA 文件未找到!"
    exit 1
fi

if [ -d "${ARCHIVE_PATH}/dSYMs" ] && [ "$(ls -A "${ARCHIVE_PATH}/dSYMs")" ]; then
    cp -r "${ARCHIVE_PATH}/dSYMs" "${PACKAGE_DIR}/"
else
    echo "警告: dSYMs 目录为空或不存在!"
    mkdir -p "${PACKAGE_DIR}/dSYMs"
fi

# 打包IPA和dSYM
cd "${PACKAGE_DIR}"
zip -r "${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.zip" ./
cd "${WORKSPACE}"

# 非本地打包时上传文件并删除本地zip
if [ "$LOCALPACKAGE" != "true" ]; then
    python3 artifactory_utils.py --action=upload_file --file="${TARGET_NAME}_${BUILD_NUMBER}.zip" --project
    rm -f "${TARGET_NAME}_${BUILD_NUMBER}.zip"
fi

# 清理文件
rm -rf ${TARGET_NAME}_${BUILD_NUMBER}.xcarchive
rm -rf ${PACKAGE_DIR}
rm -rf ${EXPORT_PATH}

# 复原Keycenter文件
python3 ./cicd/build_scripts/modify_ios_keycenter.py $KEYCENTER_PATH 1

echo '打包完成'
