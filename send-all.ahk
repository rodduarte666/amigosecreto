#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2

global AbortSend := false
global PageLoadWait := 7500
global AfterSendWait := 1600

F8::StartSend()
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

    urls := []
    text := FileRead(queuePath, "UTF-8")
    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line, " `t`r`n" Chr(0xFEFF))
        if (line != "")
            urls.Push(line)
    }

    if (urls.Length = 0) {
        MsgBox("A fila está vazia.", "Amigo Secreto", "Iconx")
        return
    }

    answer := MsgBox(
        "Encontrei " urls.Length " mensagens na fila.`n`n" .
        "O script vai abrir cada conversa no WhatsApp Web e pressionar Enter automaticamente.`n`n" .
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
        Loop urls.Length {
            if AbortSend
                break

            url := urls[A_Index]

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

            ToolTip("Carregando " A_Index "/" urls.Length "…")
            Sleep(PageLoadWait)

            if AbortSend
                break

            if WinExist("WhatsApp") {
                WinActivate("WhatsApp")
                WinWaitActive("WhatsApp", , 5)
            }

            Send("{Enter}")
            sent += 1
            ToolTip("Enviado " sent "/" urls.Length)
            Sleep(AfterSendWait)
        }
    } finally {
        A_Clipboard := oldClip
        ToolTip("")
    }

    if AbortSend
        MsgBox("Envio cancelado. Foram enviados " sent " de " urls.Length ".", "Amigo Secreto", "Icon!")
    else
        MsgBox("Pronto — " sent " mensagens enviadas.", "Amigo Secreto", "Iconi")
}

GetDownloadsFolder() {
    try {
        path := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "{374DE290-123F-4565-9164-39C4925E467B}")
        path := StrReplace(path, "%USERPROFILE%", A_UserProfile)
        if DirExist(path)
            return path
    }
    return A_UserProfile "\Downloads"
}

; Também pode pressionar F8 para repetir a fila sem fechar o script.
StartSend()
