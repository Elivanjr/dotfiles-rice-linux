pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool busy: false
    property string error: ""
    property var posts: []
    property var favorites: []
    property var suggestions: []
    property string ikachanConfigPath: Quickshell.env("HOME") + "/Downloads/ikachan/ikachan.json"
    readonly property var ikachan: ikachanAdapter.config
    property string provider: ikachan.site || "safebooru"
    property bool allowNsfw: false
    property int page: 1
    property int limit: 20

    property var providers: {
        const result = {
            yandere: { label: "yande.re", endpoint: "https://yande.re/post.json", description: "Equilibrado: boa qualidade e variedade" },
            konachan: { label: "Konachan", endpoint: "https://konachan.net/post.json", description: "Voltado a wallpapers" },
            danbooru: { label: "Danbooru", endpoint: "https://danbooru.donmai.us/posts.json", description: "Catálogo muito grande" },
            gelbooru: { label: "Gelbooru", endpoint: "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1", description: "Catálogo amplo, incluindo NSFW" },
            safebooru: { label: "Safebooru", endpoint: "https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1", description: "Somente conteúdo seguro" },
            alcy: { label: "Alcy", endpoint: "https://t.alcy.cc/", description: "Imagens grandes, somente SFW" }
        }
        for (const customSite of ikachan.custom_sites) {
            if (customSite.type === "moebooru" && customSite.name && customSite.host) {
                result[customSite.name] = { label: customSite.name, endpoint: "https://" + customSite.host + "/post.json", description: "Site Moebooru personalizado (Ikachan)" }
            }
        }
        return result
    }
    readonly property var providerNames: Object.keys(providers)

    property var ikachanFile: FileView {
        path: root.ikachanConfigPath
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: ikachanAdapter
            readonly property IkachanSettings config: IkachanSettings {}
        }
    }

    component CustomSite: JsonObject {
        property string type: ""
        property string name: ""
        property string host: ""
    }

    component IkachanSettings: JsonObject {
        property int thumb_size: 158
        property string thumb_mode: "rowpack"
        property string save_path: ""
        property string site: "safebooru"
        property bool infinite_scroll: true
        property list<CustomSite> custom_sites: []
    }

    function addFavorite(post) {
        if (!post || favorites.some(function(item) { return item.file === post.file }))
            return
        favorites = favorites.concat([post])
    }

    function request(tags, requestedPage, append) {
        const appendResults = append === true
        busy = true
        error = ""
        page = requestedPage || 1
        const url = buildUrl(tags, page)
        const xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        if (provider === "konachan" || provider === "danbooru")
            xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (BooruViewer/1.0)")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            busy = false
            if (xhr.status < 200 || xhr.status >= 300) {
                error = "A busca falhou (HTTP " + xhr.status + "). O provedor pode estar bloqueando a requisição."
                return
            }
            try {
                const receivedPosts = provider === "alcy" ? normalizeAlcy(xhr.responseText) : normalize(JSON.parse(xhr.responseText), provider)
                posts = appendResults ? posts.concat(receivedPosts) : receivedPosts
                if (receivedPosts.length === 0)
                    error = "Nenhuma imagem encontrada para esta busca."
            } catch (exception) {
                error = "Não foi possível interpretar a resposta do provedor."
                console.warn("Booru parse error:", exception)
            }
        }
        xhr.send()
    }

    function buildUrl(tags, requestedPage) {
        const query = tags.trim()
        const safeTag = allowNsfw || provider === "safebooru" ? "" : ((provider === "gelbooru" ? " rating:general" : " rating:safe"))
        const encoded = encodeURIComponent(query + safeTag)
        if (provider === "gelbooru" || provider === "safebooru")
            return providers[provider].endpoint + "&tags=" + encoded + "&limit=" + limit + "&pid=" + requestedPage
        if (provider === "alcy")
            return providers[provider].endpoint + encodeURIComponent(query || "ycy") + "?json&quantity=" + limit
        return providers[provider].endpoint + "?tags=" + encoded + "&limit=" + limit + "&page=" + requestedPage
    }

    function normalize(payload, source) {
        if (source === "gelbooru" || source === "safebooru") payload = Array.isArray(payload) ? payload : (payload.post || [])
        return payload.map(function(item) {
            if (source === "danbooru") return post(item.id, item.preview_file_url, item.large_file_url || item.file_url, item.tag_string, item.rating !== "s", item.image_width, item.image_height, item.source)
            return post(item.id, item.preview_url, item.sample_url || item.file_url, item.tags, item.rating !== "s" && item.rating !== "general", item.width, item.height, item.source)
        })
    }

    function normalizeAlcy(responseText) {
        return responseText.trim().split("\n").filter(Boolean).map(function(url, index) {
            return post("alcy-" + index, url, url, "[sem tags]", false, 1, 1, "")
        })
    }

    function post(id, preview, file, tags, nsfw, width, height, source) {
        return { id: id, preview: preview || file, file: file || preview, tags: tags || "", nsfw: nsfw, width: width || 1, height: height || 1, source: source || "" }
    }
}
