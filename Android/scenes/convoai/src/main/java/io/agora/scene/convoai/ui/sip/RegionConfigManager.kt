package io.agora.scene.convoai.ui.sip

import io.agora.scene.convoai.api.CovSipCallee

/**
 * Enum representing a region configuration (countries and regions)
 */
enum class RegionConfig(val flagEmoji: String, val dialCode: String, val displayName: String) {
    // Asia
    CN("🇨🇳", "+86", "China"),
    JP("🇯🇵", "+81", "Japan"),
    KR("🇰🇷", "+82", "South Korea"),
    IN("🇮🇳", "+91", "India"),
    SG("🇸🇬", "+65", "Singapore"),
    TH("🇹🇭", "+66", "Thailand"),
    MY("🇲🇾", "+60", "Malaysia"),
    ID("🇮🇩", "+62", "Indonesia"),
    PH("🇵🇭", "+63", "Philippines"),
    VN("🇻🇳", "+84", "Vietnam"),
    TW("🇹🇼", "+886", "Taiwan"),
    HK("🇭🇰", "+852", "Hong Kong"),
    MO("🇲🇴", "+853", "Macau"),
    
    // Europe
    GB("🇬🇧", "+44", "United Kingdom"),
    DE("🇩🇪", "+49", "Germany"),
    FR("🇫🇷", "+33", "France"),
    IT("🇮🇹", "+39", "Italy"),
    ES("🇪🇸", "+34", "Spain"),
    RU("🇷🇺", "+7", "Russia"),
    NL("🇳🇱", "+31", "Netherlands"),
    CH("🇨🇭", "+41", "Switzerland"),
    AT("🇦🇹", "+43", "Austria"),
    BE("🇧🇪", "+32", "Belgium"),
    SE("🇸🇪", "+46", "Sweden"),
    NO("🇳🇴", "+47", "Norway"),
    DK("🇩🇰", "+45", "Denmark"),
    FI("🇫🇮", "+358", "Finland"),
    PL("🇵🇱", "+48", "Poland"),
    CZ("🇨🇿", "+420", "Czech Republic"),
    HU("🇭🇺", "+36", "Hungary"),
    RO("🇷🇴", "+40", "Romania"),
    BG("🇧🇬", "+359", "Bulgaria"),
    GR("🇬🇷", "+30", "Greece"),
    PT("🇵🇹", "+351", "Portugal"),
    IE("🇮🇪", "+353", "Ireland"),
    LU("🇱🇺", "+352", "Luxembourg"),
    
    // North America
    US("🇺🇸", "+1", "United States"),
    CA("🇨🇦", "+1", "Canada"),
    MX("🇲🇽", "+52", "Mexico"),
    
    // South America
    BR("🇧🇷", "+55", "Brazil"),
    AR("🇦🇷", "+54", "Argentina"),
    CL("🇨🇱", "+56", "Chile"),
    CO("🇨🇴", "+57", "Colombia"),
    PE("🇵🇪", "+51", "Peru"),
    VE("🇻🇪", "+58", "Venezuela"),
    UY("🇺🇾", "+598", "Uruguay"),
    PY("🇵🇾", "+595", "Paraguay"),
    BO("🇧🇴", "+591", "Bolivia"),
    EC("🇪🇨", "+593", "Ecuador"),
    GY("🇬🇾", "+592", "Guyana"),
    SR("🇸🇷", "+597", "Suriname"),
    
    // Africa
    ZA("🇿🇦", "+27", "South Africa"),
    EG("🇪🇬", "+20", "Egypt"),
    NG("🇳🇬", "+234", "Nigeria"),
    KE("🇰🇪", "+254", "Kenya"),
    MA("🇲🇦", "+212", "Morocco"),
    TN("🇹🇳", "+216", "Tunisia"),
    DZ("🇩🇿", "+213", "Algeria"),
    GH("🇬🇭", "+233", "Ghana"),
    ET("🇪🇹", "+251", "Ethiopia"),
    UG("🇺🇬", "+256", "Uganda"),
    TZ("🇹🇿", "+255", "Tanzania"),
    ZW("🇿🇼", "+263", "Zimbabwe"),
    ZM("🇿🇲", "+260", "Zambia"),
    BW("🇧🇼", "+267", "Botswana"),
    NA("🇳🇦", "+264", "Namibia"),
    MW("🇲🇼", "+265", "Malawi"),
    MZ("🇲🇿", "+258", "Mozambique"),
    MG("🇲🇬", "+261", "Madagascar"),
    MU("🇲🇺", "+230", "Mauritius"),
    SC("🇸🇨", "+248", "Seychelles"),
    RE("🇷🇪", "+262", "Réunion"),
    
    // Oceania
    AU("🇦🇺", "+61", "Australia"),
    NZ("🇳🇿", "+64", "New Zealand"),
    FJ("🇫🇯", "+679", "Fiji"),
    PG("🇵🇬", "+675", "Papua New Guinea"),
    NC("🇳🇨", "+687", "New Caledonia"),
    VU("🇻🇺", "+678", "Vanuatu"),
    SB("🇸🇧", "+677", "Solomon Islands"),
    TO("🇹🇴", "+676", "Tonga"),
    WS("🇼🇸", "+685", "Samoa"),
    KI("🇰🇮", "+686", "Kiribati"),
    TV("🇹🇻", "+688", "Tuvalu"),
    NR("🇳🇷", "+674", "Nauru"),
    PW("🇵🇼", "+680", "Palau"),
    MH("🇲🇭", "+692", "Marshall Islands"),
    FM("🇫🇲", "+691", "Micronesia"),
    
    // Middle East
    AE("🇦🇪", "+971", "United Arab Emirates"),
    SA("🇸🇦", "+966", "Saudi Arabia"),
    QA("🇶🇦", "+974", "Qatar"),
    KW("🇰🇼", "+965", "Kuwait"),
    BH("🇧🇭", "+973", "Bahrain"),
    OM("🇴🇲", "+968", "Oman"),
    JO("🇯🇴", "+962", "Jordan"),
    LB("🇱🇧", "+961", "Lebanon"),
    SY("🇸🇾", "+963", "Syria"),
    IQ("🇮🇶", "+964", "Iraq"),
    IR("🇮🇷", "+98", "Iran"),
    IL("🇮🇱", "+972", "Israel"),
    PS("🇵🇸", "+970", "Palestine"),
    TR("🇹🇷", "+90", "Turkey"),
    CY("🇨🇾", "+357", "Cyprus"),
    
    // Other Important Countries
    IS("🇮🇸", "+354", "Iceland"),
    MT("🇲🇹", "+356", "Malta"),
    EE("🇪🇪", "+372", "Estonia"),
    LV("🇱🇻", "+371", "Latvia"),
    LT("🇱🇹", "+370", "Lithuania"),
    SK("🇸🇰", "+421", "Slovakia"),
    SI("🇸🇮", "+386", "Slovenia"),
    HR("🇭🇷", "+385", "Croatia"),
    RS("🇷🇸", "+381", "Serbia"),
    BA("🇧🇦", "+387", "Bosnia and Herzegovina"),
    ME("🇲🇪", "+382", "Montenegro"),
    MK("🇲🇰", "+389", "North Macedonia"),
    AL("🇦🇱", "+355", "Albania"),
    XK("🇽🇰", "+383", "Kosovo"),
    MD("🇲🇩", "+373", "Moldova"),
    UA("🇺🇦", "+380", "Ukraine"),
    BY("🇧🇾", "+375", "Belarus"),
    GE("🇬🇪", "+995", "Georgia"),
    AM("🇦🇲", "+374", "Armenia"),
    AZ("🇦🇿", "+994", "Azerbaijan"),
    KZ("🇰🇿", "+7", "Kazakhstan"),
    UZ("🇺🇿", "+998", "Uzbekistan"),
    KG("🇰🇬", "+996", "Kyrgyzstan"),
    TJ("🇹🇯", "+992", "Tajikistan"),
    TM("🇹🇲", "+993", "Turkmenistan"),
    AF("🇦🇫", "+93", "Afghanistan"),
    PK("🇵🇰", "+92", "Pakistan"),
    BD("🇧🇩", "+880", "Bangladesh"),
    LK("🇱🇰", "+94", "Sri Lanka"),
    MV("🇲🇻", "+960", "Maldives"),
    BT("🇧🇹", "+975", "Bhutan"),
    NP("🇳🇵", "+977", "Nepal"),
    MM("🇲🇲", "+95", "Myanmar"),
    LA("🇱🇦", "+856", "Laos"),
    KH("🇰🇭", "+855", "Cambodia"),
    BN("🇧🇳", "+673", "Brunei"),
    TL("🇹🇱", "+670", "East Timor"),
    MN("🇲🇳", "+976", "Mongolia"),
    KP("🇰🇵", "+850", "North Korea");
    
    /**
     * Get region code (enum name)
     */
    val regionCode: String get() = name
}

/**
 * Extension functions for RegionConfig to work with CovSipCallee
 */
fun RegionConfigManager.findByRegionCode(regionCode: String): RegionConfig? {
    return allRegions.firstOrNull { 
        it.regionCode == regionCode.uppercase() 
    }
}

fun RegionConfigManager.fromSipCallees(sipCallees: List<CovSipCallee>): List<RegionConfig> {
    return sipCallees.mapNotNull { callee ->
        findByRegionCode(callee.region_name)
    }.distinctBy { it.regionCode }
}

/**
 * Region Configuration Manager
 * Now using enum for better performance and type safety
 */
object RegionConfigManager {
    
    /**
     * All regions configuration (countries and regions)
     * Now using enum values directly
     */
    val allRegions: List<RegionConfig> = RegionConfig.values().toList()
    
    /**
     * Get region by region code
     */
    fun getRegionByCode(regionCode: String): RegionConfig? {
        return allRegions.find { it.regionCode == regionCode }
    }
    
    /**
     * Get region by display name (case insensitive)
     */
    fun getRegionByDisplayName(displayName: String): RegionConfig? {
        return allRegions.find { it.displayName.equals(displayName, ignoreCase = true) }
    }
    
    /**
     * Get region by dial code (returns first match)
     * WARNING: Multiple countries may share the same dial code (e.g., US and Canada both use +1)
     */
    fun getRegionByDialCode(dialCode: String): RegionConfig? {
        return allRegions.find { it.dialCode == dialCode }
    }
    
    /**
     * Get all regions by dial code
     * Use this when multiple countries share the same dial code
     */
    fun getAllRegionsByDialCode(dialCode: String): List<RegionConfig> {
        return allRegions.filter { it.dialCode == dialCode }
    }
    
    /**
     * Search regions by partial name match (case insensitive)
     */
    fun searchRegionsByName(query: String): List<RegionConfig> {
        if (query.isBlank()) return allRegions
        return allRegions.filter { 
            it.displayName.contains(query, ignoreCase = true) ||
            it.regionCode.contains(query, ignoreCase = true)
        }
    }
    
    /**
     * Get regions grouped by continent/region
     */
    fun getRegionsByContinent(): Map<String, List<RegionConfig>> {
        return mapOf(
            "Asia" to allRegions.filter { it.regionCode in listOf("CN", "JP", "KR", "IN", "SG", "TH", "MY", "ID", "PH", "VN", "TW", "HK", "MO", "AF", "PK", "BD", "LK", "MV", "BT", "NP", "MM", "LA", "KH", "BN", "TL", "MN", "KP") },
            "Europe" to allRegions.filter { it.regionCode in listOf("GB", "DE", "FR", "IT", "ES", "RU", "NL", "CH", "AT", "BE", "SE", "NO", "DK", "FI", "PL", "CZ", "HU", "RO", "BG", "GR", "PT", "IE", "LU", "IS", "MT", "EE", "LV", "LT", "SK", "SI", "HR", "RS", "BA", "ME", "MK", "AL", "XK", "MD", "UA", "BY", "GE", "AM", "AZ", "KZ", "UZ", "KG", "TJ", "TM") },
            "North America" to allRegions.filter { it.regionCode in listOf("US", "CA", "MX") },
            "South America" to allRegions.filter { it.regionCode in listOf("BR", "AR", "CL", "CO", "PE", "VE", "UY", "PY", "BO", "EC", "GY", "SR") },
            "Africa" to allRegions.filter { it.regionCode in listOf("ZA", "EG", "NG", "KE", "MA", "TN", "DZ", "GH", "ET", "UG", "TZ", "ZW", "ZM", "BW", "NA", "MW", "MZ", "MG", "MU", "SC", "RE") },
            "Oceania" to allRegions.filter { it.regionCode in listOf("AU", "NZ", "FJ", "PG", "NC", "VU", "SB", "TO", "WS", "KI", "TV", "NR", "PW", "MH", "FM") },
            "Middle East" to allRegions.filter { it.regionCode in listOf("AE", "SA", "QA", "KW", "BH", "OM", "JO", "LB", "SY", "IQ", "IR", "IL", "PS", "TR", "CY") }
        )
    }
    
    /**
     * Get dial codes that are shared by multiple countries
     * This helps identify potential conflicts in dial code lookup
     */
    fun getSharedDialCodes(): Map<String, List<RegionConfig>> {
        return allRegions.groupBy { it.dialCode }
            .filter { it.value.size > 1 }
    }
    
    /**
     * Check if a dial code is shared by multiple countries
     */
    fun isDialCodeShared(dialCode: String): Boolean {
        return allRegions.count { it.dialCode == dialCode } > 1
    }
}
