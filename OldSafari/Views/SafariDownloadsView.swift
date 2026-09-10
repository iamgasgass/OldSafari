// SOSTITUISCE il file "01_SafariDownloadsView_FIX_compile+buttons".
// SOSTITUISCI in OldSafari/Views/SafariDownloadsView.swift il computed var
// `trailingButtons` e la struct `OldOSDownloadIconButton` con questi blocchi.
// `OldOSDownloadGlyph` resta invariata (i path vettoriali dei glifi vanno bene).

@ViewBuilder
private var trailingButtons: some View {
    switch download.state {
    case .running:
        OldOSDownloadIconButton(kind: .cancel, theme: theme, action: onCancel)
    case .completed:
        HStack(spacing: 7) {
            OldOSDownloadIconButton(kind: .folder, theme: theme, action: onOpen)
            OldOSDownloadIconButton(kind: .share, theme: theme, action: onShare)
            OldOSDownloadIconButton(kind: .trash, theme: theme, action: onDelete)
        }
    case .failed, .cancelled:
        OldOSDownloadIconButton(kind: .trash, theme: theme, action: onDelete)
    }
}

private struct OldOSDownloadIconButton: View {
    enum Kind { case folder, share, trash, cancel }

    let kind: Kind
    // FIX compilazione: `theme` non era dichiarato qui — un tipo annidato
    // non eredita le proprietà dell'istanza esterna (DownloadRow). Va
    // passato esplicitamente, sia qui che ai 4 call site sopra.
    let theme: OldOSSafariTheme
    let action: () -> Void

    // Stesso sistema cromatico di OldOSRectangleButton (usato in tutta
    // l'app: title bar, toolbar, action sheet) invece di un'icona "nuda"
    // senza chrome — questo è ciò che rende il pulsante maniacalmente
    // coerente con il resto della UI iOS 6.
    private var buttonType: OldOSButtonType {
        kind == .trash || kind == .cancel ? .red : theme.secondaryButton
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            OldOSDownloadGlyph(kind: kind, color: .white)
                .frame(width: 17, height: 17)
                .frame(width: 32, height: 32)
                .oldOSInnerShadowBackground(
                    RoundedRectangle(cornerRadius: 5.5),
                    oldOSButtonGradient(buttonType),
                    radius: 0.8,
                    offset: CGPoint(x: 0, y: 0.6),
                    intensity: 0.7
                )
                .oldOSStrokeRoundedRectangle(5.5, Color.black.opacity(0.35), lineWidth: 0.5)
                .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
                .contentShape(RoundedRectangle(cornerRadius: 5.5))
        }
        .buttonStyle(.plain)
    }
}

// Nota: il glifo ora è sempre bianco (era condizionalmente colorato solo
// per trash/cancel) perché il colore semantico (grigio-blu per le azioni
// neutre, rosso per quelle distruttive) è ora nel FONDO del pulsante
// tramite `buttonType`, esattamente come ogni altro OldOSRectangleButton
// dell'app — non più nel tratto dell'icona.
