'-------------------------------------------------------------------------------
' init
'-------------------------------------------------------------------------------
sub init()
    m.log = CreateLogger("ArtistTask")
    m.top.functionName = "executeRequest"
end sub

'-------------------------------------------------------------------------------
' executeRequest
'-------------------------------------------------------------------------------
sub executeRequest()
    request = m.top.request
    validationError = validateRequest(request)
    if validationError <> invalid then
        m.top.response = validationError
        return
    end if

    artistId = String_Trim(SafeString(request.artistId, ""))
    musicBrainzResult = loadMusicBrainzArtist(artistId)
    if musicBrainzResult.ok <> true then
        m.top.response = buildErrorResponse(artistId, SafeString(musicBrainzResult.errorMessage, "Unable to load MusicBrainz artist."))
        return
    end if

    wikipediaTarget = getWikipediaTarget(musicBrainzResult.data)
    if wikipediaTarget = invalid then
        m.top.response = buildErrorResponse(artistId, "No Wikipedia page is linked to this MusicBrainz artist.")
        return
    end if

    summaryResult = loadWikipediaSummary(wikipediaTarget)
    if summaryResult.ok <> true then
        m.top.response = buildErrorResponse(artistId, SafeString(summaryResult.errorMessage, "Unable to load Wikipedia overview."))
        return
    end if

    summary = summaryResult.data
    extract = SafeString(summary.extract, "")
    if extract = "" then
        m.top.response = buildErrorResponse(artistId, "Wikipedia did not return an artist overview.")
        return
    end if

    m.top.response = {
        ok: true
        action: "musicArtist"
        artistId: artistId
        title: SafeString(summary.title, "")
        extract: extract
        wikipediaUrl: getWikipediaPageUrl(summary, wikipediaTarget)
        thumbnailUrl: getWikipediaThumbnailUrl(summary)
    }
end sub

'-------------------------------------------------------------------------------
' loadMusicBrainzArtist
'-------------------------------------------------------------------------------
function loadMusicBrainzArtist(artistId as string) as object
    url = "https://musicbrainz.org/ws/2/artist/" + Encode_Url(artistId) + "?inc=url-rels&fmt=json"
    return HttpClient_Request(url, "GET", invalid, invalid, getExternalApiHeaders())
end function

'-------------------------------------------------------------------------------
' getWikipediaTarget
'-------------------------------------------------------------------------------
function getWikipediaTarget(artist as dynamic) as dynamic
    if Array_IsAssocArray(artist) = false or artist.relations = invalid then return invalid

    englishWikipediaUrl = ""
    fallbackWikipediaUrl = ""
    wikidataUrl = ""

    for each relation in artist.relations
        if Array_IsAssocArray(relation) = false or relation.url = invalid then continue for

        resource = SafeString(relation.url.resource, "")
        relationType = LCase(SafeString(relation.type, ""))
        if relationType = "wikipedia" then
            if isEnglishWikipediaUrl(resource) then
                englishWikipediaUrl = resource
            else if fallbackWikipediaUrl = "" then
                fallbackWikipediaUrl = resource
            end if
        else if relationType = "wikidata" and wikidataUrl = "" then
            wikidataUrl = resource
        end if
    end for

    if englishWikipediaUrl <> "" then return createWikipediaTarget(englishWikipediaUrl)

    if wikidataUrl <> "" then
        target = loadEnglishWikipediaTargetFromWikidata(wikidataUrl)
        if target <> invalid then return target
    end if

    if fallbackWikipediaUrl <> "" then return createWikipediaTarget(fallbackWikipediaUrl)
    return invalid
end function

'-------------------------------------------------------------------------------
' loadEnglishWikipediaTargetFromWikidata
'-------------------------------------------------------------------------------
function loadEnglishWikipediaTargetFromWikidata(wikidataUrl as string) as dynamic
    entityId = getLastUrlPathSegment(wikidataUrl)
    if entityId = "" then return invalid

    url = "https://www.wikidata.org/wiki/Special:EntityData/" + Encode_Url(entityId) + ".json"
    response = HttpClient_Request(url, "GET", invalid, invalid, getExternalApiHeaders())
    if response.ok <> true or response.data = invalid or response.data.entities = invalid then return invalid

    entity = response.data.entities[entityId]
    if entity = invalid or entity.sitelinks = invalid or entity.sitelinks.enwiki = invalid then return invalid

    title = SafeString(entity.sitelinks.enwiki.title, "")
    if title = "" then return invalid

    return {
        language: "en"
        title: title
        summaryPath: Encode_Url(title)
        pageUrl: "https://en.wikipedia.org/wiki/" + Encode_Url(title)
    }
end function

'-------------------------------------------------------------------------------
' createWikipediaTarget
'-------------------------------------------------------------------------------
function createWikipediaTarget(wikipediaUrl as string) as dynamic
    wikiMarker = ".wikipedia.org/wiki/"
    markerIndex = Instr(1, LCase(wikipediaUrl), wikiMarker)
    if markerIndex = 0 then return invalid

    schemeEnd = Instr(1, wikipediaUrl, "://")
    if schemeEnd = 0 then return invalid

    hostStart = schemeEnd + 3
    languageEnd = Instr(hostStart, wikipediaUrl, ".")
    if languageEnd = 0 then return invalid

    titleStart = markerIndex + Len(wikiMarker)
    title = Mid(wikipediaUrl, titleStart)
    if title = "" then return invalid

    return {
        language: Mid(wikipediaUrl, hostStart, languageEnd - hostStart)
        title: title
        summaryPath: title
        pageUrl: wikipediaUrl
    }
end function

'-------------------------------------------------------------------------------
' loadWikipediaSummary
'-------------------------------------------------------------------------------
function loadWikipediaSummary(target as object) as object
    language = SafeString(target.language, "en")
    summaryPath = SafeString(target.summaryPath, "")
    url = "https://" + language + ".wikipedia.org/api/rest_v1/page/summary/" + summaryPath
    return HttpClient_Request(url, "GET", invalid, invalid, getExternalApiHeaders())
end function

'-------------------------------------------------------------------------------
' getWikipediaPageUrl
'-------------------------------------------------------------------------------
function getWikipediaPageUrl(summary as object, target as object) as string
    if summary.content_urls <> invalid and summary.content_urls.desktop <> invalid then
        pageUrl = SafeString(summary.content_urls.desktop.page, "")
        if pageUrl <> "" then return pageUrl
    end if

    return SafeString(target.pageUrl, "")
end function

'-------------------------------------------------------------------------------
' getWikipediaThumbnailUrl
'-------------------------------------------------------------------------------
function getWikipediaThumbnailUrl(summary as object) as string
    if summary.thumbnail = invalid then return ""
    return SafeString(summary.thumbnail.source, "")
end function

'-------------------------------------------------------------------------------
' isEnglishWikipediaUrl
'-------------------------------------------------------------------------------
function isEnglishWikipediaUrl(url as string) as boolean
    return Instr(1, LCase(url), "://en.wikipedia.org/wiki/") > 0
end function

'-------------------------------------------------------------------------------
' getLastUrlPathSegment
'-------------------------------------------------------------------------------
function getLastUrlPathSegment(url as string) as string
    normalizedUrl = url
    while Right(normalizedUrl, 1) = "/"
        normalizedUrl = Left(normalizedUrl, Len(normalizedUrl) - 1)
    end while

    slashIndex = 0
    searchIndex = 1
    while true
        nextSlashIndex = Instr(searchIndex, normalizedUrl, "/")
        if nextSlashIndex = 0 then exit while
        slashIndex = nextSlashIndex
        searchIndex = nextSlashIndex + 1
    end while

    if slashIndex = 0 then return ""
    return Mid(normalizedUrl, slashIndex + 1)
end function

'-------------------------------------------------------------------------------
' getExternalApiHeaders
'-------------------------------------------------------------------------------
function getExternalApiHeaders() as object
    return {
        "User-Agent": "Starfin-Roku/1.0 (https://github.com/thedavidhoffman/starfin-roku)"
    }
end function

'-------------------------------------------------------------------------------
' buildErrorResponse
'-------------------------------------------------------------------------------
function buildErrorResponse(artistId as string, message as string) as object
    return {
        ok: false
        action: "musicArtist"
        artistId: artistId
        errorMessage: message
    }
end function

'-------------------------------------------------------------------------------
' validateRequest
'-------------------------------------------------------------------------------
function validateRequest(request as dynamic) as dynamic
    if request = invalid then return buildErrorResponse("", "Invalid music artist request.")

    artistId = String_Trim(SafeString(request.artistId, ""))
    if artistId = "" then return buildErrorResponse("", "Invalid MusicBrainz artist ID.")

    return invalid
end function
