# convo ai cn cicd
export LANG=en_US.UTF-8

export PATH=$PATH:/opt/homebrew/bin

# 设置全局变量
if [ -z "$WORKSPACE" ]; then
    export WORKSPACE=$(pwd)/cicd/iosExport
    export LOCALPACKAGE="true"
    mkdir -p $WORKSPACE
fi

if [ -z "$BUILD_NUMBER" ]; then
    export BUILD_NUMBER=$(date +%Y%m%d%H%M%S)
fi

if [ -z "$build_date" ]; then
    export build_date=$(date +%Y%m%d)
fi

if [ -z "$build_time" ]; then
    export build_time=$(date +%H%M%S)
fi

CURRENT_PATH=$PWD

# 项目target名
PROJECT_NAME=Agent
TARGET_NAME=Agent-cn

# 获取项目目录
PROJECT_PATH="${CURRENT_PATH}/iOS"
if [ ! -d "${PROJECT_PATH}" ]; then
    echo "错误: 找不到 iOS 目录: ${PROJECT_PATH}"
    echo "构建失败: iOS 项目目录不存在"
    exit 1
fi

if [ -z "$toolbox_url" ]; then
    export toolbox_url="https://service.apprtc.cn/toolbox"
fi

if [[ "${toolbox_url}" != *"https://"* ]]; then
    toolbox_url="https://${toolbox_url}"
fi

# 根据 toolbox_url 关键词选择对应的 APP_ID
if [[ "${toolbox_url}" == *"dev"* ]]; then
    echo "使用开发环境 APP_ID (dev)"
    if [ -n "$APP_ID_DEV" ]; then
        APP_ID=${APP_ID_DEV}
    else
        echo "警告: APP_ID_DEV 环境变量未设置"
    fi
elif [[ "${toolbox_url}" == *"staging"* ]]; then
    echo "使用测试环境 APP_ID (staging)"
    if [ -n "$APP_ID_STAGING" ]; then
        APP_ID=${APP_ID_STAGING}
    else
        echo "警告: APP_ID_STAGING 环境变量未设置"
    fi
else
    echo "使用生产环境 APP_ID (prod)"
    if [ -n "$APP_ID_PROD" ]; then
        APP_ID=${APP_ID_PROD}
    else
        echo "警告: APP_ID_PROD 环境变量未设置"
    fi
fi

if [ -z "$APP_ID" ]; then
    echo "警告: 所有 APP_ID 环境变量都未设置，将使用默认空值"
    APP_ID=""
fi

if [ "$upload_app_store" = "true" ]; then
    export method="app-store"
    echo "设置导出方式为: app-store (app-store 包)"
else
    export method="development"
    echo "设置导出方式为: development (测试包)"
fi

if [ -z "$bundleId" ]; then
    export bundleId="cn.shengwang.convoai"
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

# 检查关键环境变量
echo "检查iOS构建环境变量:"
echo "Xcode 版本: $(xcodebuild -version | head -n 1)"
echo "Swift 版本: $(swift --version | head -n 1)"
echo "Ruby 版本: $(ruby --version)"
echo "CocoaPods 版本: $(pod --version)"

echo PROJECT_PATH: $PROJECT_PATH
echo TARGET_NAME: $TARGET_NAME
echo pwd: $CURRENT_PATH

# 下载环境配置文件
echo "开始下载环境配置文件..."
ASSETS_DIR="${PROJECT_PATH}/Common/Common/Assets"
mkdir -p "${ASSETS_DIR}"

# 确保 dev_env_config_url 包含 https:// 前缀
if [[ ! -z ${dev_env_config_url} ]]; then
    if [[ "${dev_env_config_url}" != *"https://"* ]]; then
        # 如果 URL 不包含 https:// 前缀，添加它
        dev_env_config_url="https://${dev_env_config_url}"
        echo "为配置文件 URL 添加 https 前缀：${dev_env_config_url}"
    fi

    echo "下载环境配置文件：${dev_env_config_url}"
    curl -L -v -H "X-JFrog-Art-Api:${JFROG_API_KEY}" -o "${ASSETS_DIR}/dev_env_config.json" "${dev_env_config_url}" || exit 1
    echo "环境配置文件下载完成，保存至 ${ASSETS_DIR}/dev_env_config.json"
else
    echo "未指定 dev_env_config_url，跳过环境配置文件下载"
fi

PODFILE_PATH=${PWD}"/iOS/Podfile"

if [[ ! -z ${sdk_url} && "${sdk_url}" != 'none' ]]; then
    zip_name=${sdk_url##*/}
    curl -L -v -H "X-JFrog-Art-Api:${JFROG_API_KEY}" -O $sdk_url || exit 1
    unzip -o ./$zip_name -y

    unzip_name=`ls -S -d */ | grep Agora`
    echo unzip_name: $unzip_name

    mv "${PWD}/${unzip_name}/libs" "${PWD}/iOS"

    # 修改podfile文件
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

# 从项目配置读取版本号
export release_version=$(xcodebuild -workspace "${PROJECT_PATH}/${PROJECT_NAME}.xcworkspace" -scheme "${TARGET_NAME}" -showBuildSettings | grep "MARKETING_VERSION" | cut -d "=" -f 2 | tr -d " ")
if [ -z "$release_version" ]; then
    echo "错误: 无法从项目配置读取版本号"
    exit 1
fi
echo "从项目配置读取到版本号: ${release_version}"

# 产物名称
export ARTIFACT_NAME="ShengWang_Conversational_Al_Engine_Demo_for_iOS_v${release_version}_${BUILD_NUMBER}"

KEYCENTER_PATH=${PROJECT_PATH}"/"${PROJECT_NAME}"/KeyCenter.swift"

# 打包环境
CONFIGURATION='Release'
result=$(echo ${method} | grep "development")
if [[ ! -z "$result" ]]; then
    CONFIGURATION='Debug'
fi

# 签名配置
if [ "$method" = "app-store" ]; then
    # App Store发布配置
    PROVISIONING_PROFILE="cn.shengwang.convoai.appstore"
    CODE_SIGN_IDENTITY="iPhone Distribution"
    DEVELOPMENT_TEAM="48TB6ZZL5S"
else
    # 开发环境配置
    PROVISIONING_PROFILE="cn.shengwang.convoai.appstore"
    CODE_SIGN_IDENTITY="iPhone Distribution"
    DEVELOPMENT_TEAM="48TB6ZZL5S"
fi

#工程文件路径
APP_PATH="${PROJECT_PATH}/${PROJECT_NAME}.xcworkspace"

#工程配置路径
PBXPROJ_PATH="${PROJECT_PATH}/${PROJECT_NAME}.xcodeproj/project.pbxproj"
echo PBXPROJ_PATH: $PBXPROJ_PATH

# 验证文件存在性
echo "验证文件和目录存在性:"
if [ ! -e "${APP_PATH}" ]; then
    echo "错误: 找不到工程文件: ${APP_PATH}"
    # 寻找工作区文件
    find ${PROJECT_PATH} -name "*.xcworkspace"
    exit 1
fi

if [ ! -f "${PBXPROJ_PATH}" ]; then
    echo "错误: 找不到工程配置文件: ${PBXPROJ_PATH}"
    # 寻找 project.pbxproj 文件
    find ${PROJECT_PATH} -name "project.pbxproj" -type f
    exit 1
fi

# 主项目工程配置
# Debug
sed -i '' "s|CURRENT_PROJECT_VERSION = .*;|CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};|g" $PBXPROJ_PATH
sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = .*;|PRODUCT_BUNDLE_IDENTIFIER = \"${bundleId}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_STYLE = .*;|CODE_SIGN_STYLE = \"Manual\";|g" $PBXPROJ_PATH
sed -i '' "s|DEVELOPMENT_TEAM = .*;|DEVELOPMENT_TEAM = \"${DEVELOPMENT_TEAM}\";|g" $PBXPROJ_PATH
sed -i '' "s|PROVISIONING_PROFILE_SPECIFIER = .*;|PROVISIONING_PROFILE_SPECIFIER = \"${PROVISIONING_PROFILE}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_IDENTITY = .*;|CODE_SIGN_IDENTITY = \"${CODE_SIGN_IDENTITY}\";|g" $PBXPROJ_PATH

# Release
sed -i '' "s|CURRENT_PROJECT_VERSION = .*;|CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};|g" $PBXPROJ_PATH
sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = .*;|PRODUCT_BUNDLE_IDENTIFIER = \"${bundleId}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_STYLE = .*;|CODE_SIGN_STYLE = \"Manual\";|g" $PBXPROJ_PATH
sed -i '' "s|DEVELOPMENT_TEAM = .*;|DEVELOPMENT_TEAM = \"${DEVELOPMENT_TEAM}\";|g" $PBXPROJ_PATH
sed -i '' "s|PROVISIONING_PROFILE_SPECIFIER = .*;|PROVISIONING_PROFILE_SPECIFIER = \"${PROVISIONING_PROFILE}\";|g" $PBXPROJ_PATH
sed -i '' "s|CODE_SIGN_IDENTITY = .*;|CODE_SIGN_IDENTITY = \"${CODE_SIGN_IDENTITY}\";|g" $PBXPROJ_PATH

# 读取APPID环境变量
echo AGORA_APP_ID:$APP_ID

echo PROJECT_PATH: $PROJECT_PATH
echo PROJECT_NAME: $PROJECT_NAME
echo TARGET_NAME: $TARGET_NAME
echo KEYCENTER_PATH: $KEYCENTER_PATH
echo APP_PATH: $APP_PATH
echo manifest_url: $manifest_url

#修改Keycenter文件
# 使用 sed 替换 KeyCenter.swift 中的参数
if [ -n "$APP_ID" ]; then
    sed -i '' "s|static let AppId: String = .*|static let AppId: String = \"$APP_ID\"|g" $KEYCENTER_PATH
fi
if [ -n "$toolbox_url" ]; then
    sed -i '' "s|static let TOOLBOX_SERVER_HOST: String = .*|static let TOOLBOX_SERVER_HOST: String = \"$toolbox_url\"|g" $KEYCENTER_PATH
fi
# 替换 Certificate 为空
sed -i '' "s|static let Certificate: String? = .*|static let Certificate: String? = \"\"|g" $KEYCENTER_PATH
# 替换 manifestUrl
sed -i '' "s|let manifestUrl = .*|let manifestUrl = \"$manifest_url\"|g" $KEYCENTER_PATH

# 归档路径
ARCHIVE_PATH="${WORKSPACE}/${TARGET_NAME}_${BUILD_NUMBER}.xcarchive"

# plist路径
PLIST_PATH="${CURRENT_PATH}/cicd/build_scripts/ExportOptions_${method}.plist"

echo PLIST_PATH: $PLIST_PATH

# 构建和归档
echo "开始构建和归档..."
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

# 创建导出目录
EXPORT_PATH="${WORKSPACE}/export"
mkdir -p "${EXPORT_PATH}"

# 导出IPA
echo "开始导出IPA..."
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
    cp "${EXPORT_PATH}/${TARGET_NAME}.ipa" "${PACKAGE_DIR}/${ARTIFACT_NAME}.ipa"
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
zip -r "${WORKSPACE}/${ARTIFACT_NAME}.zip" ./
cd "${WORKSPACE}"

# 非本地打包时上传文件并删除本地zip
if [ "$LOCALPACKAGE" != "true" ]; then
    echo "上传产物到制品库..."
    
    # 上传文件到制品库并保存输出结果
    UPLOAD_RESULT=$(python3 artifactory_utils.py --action=upload_file --file="${ARTIFACT_NAME}.zip" --project)
    
    # 提取URL并保存到package_urls文件
    echo "$UPLOAD_RESULT" | grep -i "url" > ${WORKSPACE}/package_urls
    
    if [ -s ${WORKSPACE}/package_urls ]; then
        echo "===================================================="
        echo "产物上传成功! 下载地址:"
        cat ${WORKSPACE}/package_urls
        echo "===================================================="
    else
        echo "警告: 未找到上传后的下载地址"
    fi
    
    # 清理本地产物
    rm -f "${ARTIFACT_NAME}.zip"
fi

# 清理文件
rm -rf ${TARGET_NAME}_${BUILD_NUMBER}.xcarchive
rm -rf ${PACKAGE_DIR}
rm -rf ${EXPORT_PATH}

echo '打包完成'

