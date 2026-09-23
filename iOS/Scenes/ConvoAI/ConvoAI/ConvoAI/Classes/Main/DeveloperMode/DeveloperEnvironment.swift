struct DeveloperEnvironment {
    let name: String
    let host: String
    let appId: String

    static func currentIndex(
        in environments: [[String: String]],
        host: String,
        appId: String,
        selection: DeveloperEnvironment? = nil
    ) -> Int? {
        guard !host.isEmpty, !appId.isEmpty else { return nil }

        // Dynamic App IDs may be absent from the bundled list. Keep an explicit
        // selection only while both parts of its active configuration still match.
        if let selection = selection,
           selection.host == host,
           selection.appId == appId,
           let index = environments.firstIndex(where: {
               $0["toolbox_server_host"] == host && $0["env_name"] == selection.name
           }) {
            return index
        }

        return environments.firstIndex {
            $0["toolbox_server_host"] == host && $0["rtc_app_id"] == appId
        }
    }
}
