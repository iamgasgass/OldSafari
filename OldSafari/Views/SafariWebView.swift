// SOSTITUISCI in OldSafari/Views/SafariWebView.swift, dentro `final class
// Coordinator`, il metodo `contextMenuConfigurationForElement` e il metodo
// `saveImageToPhotos` con questi blocchi (aggiunge anche `confirmAndSaveImage`).
// Tutto il resto del file (JS alert, download detection, ecc.) resta invariato.

// MARK: Long press on a link / image

func webView(
    _ webView: WKWebView,
    contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
    completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
) {
    let linkURL = elementInfo.linkURL

    // FIX BUG "Salva immagine non salva nulla": WKContextMenuElementInfo non
    // espone l'URL dell'immagine, per cui viene intercettato via lo script JS
    // "oldSafariContextMenu" con un postMessage ASINCRONO. Il codice
    // precedente leggeva `contextMenuImageURL` in modo sincrono, PRIMA che
    // quel messaggio potesse arrivare: su molte pagine (Google Immagini
    // incluso) il valore era ancora nil o quello del long-press precedente.
    // Ritardare la lettura di un run loop dà tempo al messaggio di arrivare.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
        guard let self else {
            completionHandler(nil)
            return
        }
        let imageURL = self.contextMenuImageURL
        self.contextMenuImageURL = nil
        let pageURL = webView.url

        guard linkURL != nil || imageURL != nil else {
            completionHandler(nil)
            return
        }

        let configuration = UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil
        ) { [weak self] _ in
            guard let self else { return nil }
            var actions: [UIAction] = []

            if let imageURL {
                let saveImage = UIAction(
                    title: "Save Image",
                    image: UIImage(systemName: "square.and.arrow.down")
                ) { [weak self] _ in
                    self?.confirmAndSaveImage(imageURL, pageURL: pageURL)
                }
                actions.append(saveImage)
            }

            if let linkURL {
                let open = UIAction(
                    title: "Open",
                    image: UIImage(systemName: "safari")
                ) { _ in
                    webView.load(URLRequest(url: linkURL))
                }

                let newTab = UIAction(
                    title: "Open in New Page",
                    image: UIImage(systemName: "plus.square.on.square")
                ) { [weak self] _ in
                    self?.onOpenInNewTab?(linkURL)
                }

                let copy = UIAction(
                    title: "Copy Link",
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in
                    UIPasteboard.general.url = linkURL
                }

                let download = UIAction(
                    title: "Download Linked File",
                    image: UIImage(systemName: "arrow.down.circle")
                ) { _ in
                    webView.load(URLRequest(url: linkURL))
                }

                actions.append(contentsOf: [open])
                if self.onOpenInNewTab != nil { actions.append(newTab) }
                actions.append(contentsOf: [copy, download])

                let share = UIAction(
                    title: "Share…",
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { _ in
                    let controller = UIActivityViewController(
                        activityItems: [linkURL],
                        applicationActivities: nil
                    )
                    controller.overrideUserInterfaceStyle = .unspecified
                    controller.popoverPresentationController?.sourceView = webView
                    webView.window?.rootViewController?.present(controller, animated: true)
                }
                actions.append(share)
            }

            return UIMenu(
                title: imageURL != nil ? "Image" : (linkURL?.absoluteString ?? ""),
                children: actions
            )
        }

        completionHandler(configuration)
    }
}

/// Alert di conferma in stile iOS 6 (Foto 5), mostrato prima di scaricare
/// davvero l'immagine — replica il comportamento del Safari moderno (Foto 4)
/// ma con la UI classica: riusa `presentOldOSAlert`, già definito in questo
/// stesso file per gli alert JavaScript, quindi la resa è identica pixel
/// per pixel agli altri alert dell'app.
private func confirmAndSaveImage(_ url: URL, pageURL: URL?) {
    presentOldOSAlert(
        title: "Save Image",
        message: "Save this image to your Photos?",
        buttons: [("Cancel", .cancel), ("Save", .default)]
    ) { [weak self] _, index in
        guard index == 1 else { return }
        self?.saveImageToPhotos(url, referer: pageURL)
    }
}

/// WKContextMenuElementInfo supplies the resolved image URL, but does not
/// itself save anything. Fetch it as binary data, create a UIImage, then use
/// the Photos add-only API.
///
/// FIX BUG: mancava l'header `Referer`. Molti host con hotlink-protection
/// (Google Immagini / gstatic.com e CDN simili) rispondono 403 o corpo vuoto
/// a richieste "nude": `UIImage(data:)` falliva silenziosamente e il flusso
/// terminava nel `guard ... else { return }` senza alcun feedback, da qui
/// l'impressione "non succede nulla". Ora impostiamo Referer + User-Agent e,
/// in ogni esito (rete, permessi, salvataggio), mostriamo un alert iOS 6.
private func saveImageToPhotos(_ url: URL, referer: URL?) {
    var request = URLRequest(
        url: url,
        cachePolicy: .reloadIgnoringLocalCacheData,
        timeoutInterval: 30
    )
    if let referer {
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
    }
    request.setValue(
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
        forHTTPHeaderField: "User-Agent"
    )

    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
        guard let self else { return }

        guard
            error == nil,
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode),
            let data,
            let image = UIImage(data: data)
        else {
            DispatchQueue.main.async {
                self.presentOldOSAlert(
                    title: "Safari",
                    message: "The image could not be downloaded.",
                    buttons: [("OK", .default)]
                ) { _, _ in }
            }
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    self.presentOldOSAlert(
                        title: "Safari",
                        message: "Safari does not have permission to save to Photos. Enable it in Settings.",
                        buttons: [("OK", .default)]
                    ) { _, _ in }
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, _ in
                    DispatchQueue.main.async {
                        self.presentOldOSAlert(
                            title: "Safari",
                            message: success ? "Image saved to Photos." : "The image could not be saved.",
                            buttons: [("OK", .default)]
                        ) { _, _ in }
                    }
                }
            }
        }
    }.resume()
}

// PROMEMORIA: verifica che OldSafari/Info.plist contenga la chiave
// NSPhotoLibraryAddUsageDescription (stringa descrittiva). Se manca, iOS
// termina l'app al primo `PHPhotoLibrary.requestAuthorization` invece di
// mostrare il prompt — una seconda causa indipendente per cui "Salva
// immagine" può sembrare non fare nulla. Se vuoi che te lo aggiunga,
// incollami il contenuto di Info.plist.
