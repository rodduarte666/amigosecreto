#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2

global AbortSend := false
global PageLoadWait := 7500
global AfterSendWait := 1600

^+!#a::StartSend()
F9::CancelSend()

CancelSend() {
    global AbortSend
    AbortSend := true
    ToolTip("Cancelamento solicitado…")
    SetTimer(() => ToolTip(""), -1500)
}

StartSend() {
    global AbortSend, PageLoadWait, AfterSendWait
    AbortSend := false

    downloads := GetDownloadsFolder()
    queuePath := downloads "\amigo-secreto-fila.txt"

    if !FileExist(queuePath) {
        queuePath := FileSelect(1, downloads, "Selecione amigo-secreto-fila.txt", "Arquivos de texto (*.txt)")
        if !queuePath
            return
    }

    queue := []
    text := FileRead(queuePath, "UTF-8")
    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line, " `r`n" Chr(0xFEFF))
        if (line = "")
            continue

        fields := StrSplit(line, "`t")
        if (fields.Length < 4)
            continue

        queue.Push({
            phone: fields[1],
            giver: fields[2],
            longLink: fields[3],
            eventName: fields[4],
            budget: fields.Length >= 5 ? fields[5] : ""
        })
    }

    if (queue.Length = 0) {
        MsgBox(
            "A fila está vazia ou foi criada por uma versão antiga do site.`n`nBaixe a fila novamente e tente de novo.",
            "Amigo Secreto",
            "Iconx"
        )
        return
    }

    answer := MsgBox(
        "Encontrei " queue.Length " mensagens na fila.`n`n" .
        "O script vai encurtar cada link, abrir cada conversa no WhatsApp Web e pressionar Enter automaticamente.`n`n" .
        "Se o encurtador estiver indisponível, o link privado completo será usado e o envio continuará.`n`n" .
        "F9 cancela a qualquer momento.`n`nContinuar?",
        "Amigo Secreto — envio automático",
        "YesNo Icon!"
    )
    if (answer != "Yes")
        return

    Run("https://web.whatsapp.com/")
    MsgBox(
        "Confirme que o WhatsApp Web está aberto e conectado.`n`n" .
        "Quando estiver pronto, clique OK. Depois disso não use o teclado ou mouse até terminar.`n`n" .
        "F9 cancela.",
        "Amigo Secreto",
        "OK Iconi"
    )

    oldClip := A_Clipboard
    sent := 0

    try {
        Loop queue.Length {
            if AbortSend
                break

            item := queue[A_Index]
            ToolTip("Preparando link " A_Index "/" queue.Length "…")
            link := ShortenUrl(item.longLink)
            message := BuildMessage(item.giver, item.eventName, item.budget, link)
            url := "https://web.whatsapp.com/send?phone=" item.phone "&text=" UriEncode(message)

            if (A_Index = 1) {
                Run(url)
                if WinWait("WhatsApp", , 15) {
                    WinActivate("WhatsApp")
                    WinWaitActive("WhatsApp", , 5)
                }
            } else {
                if WinExist("WhatsApp") {
                    WinActivate("WhatsApp")
                    WinWaitActive("WhatsApp", , 5)
                    Send("^l")
                    Sleep(150)
                    A_Clipboard := url
                    ClipWait(1)
                    Send("^v")
                    Sleep(150)
                    Send("{Enter}")
                } else {
                    Run(url)
                }
            }

            ToolTip("Carregando " A_Index "/" queue.Length "…")
            Sleep(PageLoadWait)

            if AbortSend
                break

            if WinExist("WhatsApp") {
                WinActivate("WhatsApp")
                WinWaitActive("WhatsApp", , 5)
            }

            Send("{Enter}")
            sent += 1
            ToolTip("Enviado " sent "/" queue.Length)
            Sleep(AfterSendWait)
        }
    } finally {
        A_Clipboard := oldClip
        ToolTip("")
    }

    if AbortSend
        MsgBox("Envio cancelado. Foram enviados " sent " de " queue.Length ".", "Amigo Secreto", "Icon!")
    else
        MsgBox("Pronto — " sent " mensagens enviadas.", "Amigo Secreto", "Iconi")
}

BuildMessage(giver, eventName, budget, link) {
    message := "🎄 *" eventName "* 🎁`n`n"
        . "Oi, " giver "! Seu sorteio está pronto.`n`n"
        . "Abra seu link privado para descobrir quem você tirou:`n"
        . link

    if (budget != "")
        message .= "`n`n💰 " budget

    message .= "`n`n🤫 Não encaminhe este link — ele é só seu."
    return message
}

ShortenUrl(longUrl) {
    for domain in ["is.gd", "v.gd"] {
        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.SetTimeouts(5000, 5000, 5000, 10000)
            api := "https://" domain "/create.php?format=simple&url=" UriEncode(longUrl)
            req.Open("GET", api, false)
            req.SetRequestHeader("User-Agent", "AmigoSecretoFamily/1.0")
            req.Send()

            if (req.Status = 200) {
                shortUrl := Trim(req.ResponseText)
                if RegExMatch(shortUrl, "^https?://")
                    return shortUrl
            }
        }
        Sleep(400)
    }

    return longUrl
}

UriEncode(str) {
    size := StrPut(str, "UTF-8")
    buf := Buffer(size)
    StrPut(str, buf, , "UTF-8")
    out := ""

    Loop size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        if ((b >= 0x30 && b <= 0x39)
            || (b >= 0x41 && b <= 0x5A)
            || (b >= 0x61 && b <= 0x7A)
            || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E) {
            out .= Chr(b)
        } else {
            out .= "%" Format("{:02X}", b)
        }
    }
    return out
}

GetDownloadsFolder() {
    userProfile := EnvGet("USERPROFILE")
    try {
        path := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "{374DE290-123F-4565-9164-39C4925E467B}")
        path := StrReplace(path, "%USERPROFILE%", userProfile)
        if DirExist(path)
            return path
    }
    return userProfile "\Downloads"
}

; Ctrl+Shift+Alt+Win+A inicia a fila; F9 cancela imediatamente.
