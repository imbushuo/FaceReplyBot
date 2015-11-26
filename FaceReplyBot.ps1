Param([string]$ConfigFile)
if (!$ConfigFile)
{
    $global:config = Get-Content "$($PSScriptRoot)\config.json" -Raw | ConvertFrom-Json
}
else
{
    $global:config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
}

$BotToken = $global:config.BotToken;
$timeoutSecs = $global:config.TimeOutSeconds
$replyMap = @{ "🌚"="🌝"; "🌝"="🌚"; "→_→"="←_←"; "←_←"="→_→"; "#NSFW"="噫"}
$global:lastReplyTimes=@{}
$global:lastMessage=@{}

Function Invoke-TelegramBotAPI([parameter(Mandatory=$true)][string] $Method, [hashtable]$Parameters=@{})
{
    return Invoke-RestMethod "https://api.telegram.org/bot$BotToken/$Method" -Body $Parameters -Method Post -TimeoutSec 50
}

Function Send-TelegramMessage([parameter(Mandatory=$true)]$ChatID, [parameter(Mandatory=$true)][string]$MessageText, $ReplyTo)
{
    $result = Invoke-TelegramBotAPI "sendMessage" @{chat_id=$ChatID; text=$MessageText; reply_to_message_id=$ReplyTo}
}

Function Process-TextReply([parameter(Mandatory=$true)][string]$MessageText,
                           [parameter(Mandatory=$true)][long]$MessageID,
                           [parameter(Mandatory=$true)][long]$UserID,
                           [parameter(Mandatory=$true)][long]$ChatID)
{
    if ($replyMap.ContainsKey($MessageText))
    {
        if ($ChatID -lt 0)
        {
            if ($global:lastReplyTimes.ContainsKey($ChatID))
            {
                $span = [DateTime]::Now-$global:lastReplyTimes[$ChatID];
                if ($span.TotalSeconds -lt $global:config.ReplyResetTime)
                {
                    return
                }
                $global:lastReplyTimes[$ChatID]=[DateTime]::Now
            }
            else
            {
                $global:lastReplyTimes.Add($ChatID,[DateTime]::Now)
            }
        }
        return $replyMap[$MessageText]
    }
    else
    {
        if ($ChatID -lt 0)
        {
            if ($global:lastMessage.ContainsKey($ChatID))
            {
                if (($global:lastMessage[$ChatID].text -eq $MessageText) -and($global:lastMessage[$ChatID].user -ne $UserID ))
                {
                    $result = Invoke-TelegramBotAPI -Method "forwardMessage" -Parameters @{chat_id=$ChatID; from_chat_id=$ChatID; message_id=$global:lastMessage[$ChatId].msgid}
                    $global:lastMessage[$ChatID].text=""
                    $global:lastMessage[$ChatID].user=0
                    $global:lastMessage[$ChatID].msgid=0
                }
                else
                {
                    $global:lastMessage[$ChatId]=@{user=$UserID;text=$MessageText;msgid=$MessageID }
                }
            }
            else
            {
                $global:lastMessage.Add($ChatID,@{user=$UserID;text=$MessageText;msgid=$MessageID })
            }
        }
    }
}

$ret = Invoke-TelegramBotAPI -Method "getMe" 
if (!$ret.ok)
{
    echo "Error: $ret"
    exit
}
echo "BOT Name: $($ret.result.first_name) " 
echo "BOT Username: $($ret.result.username)"
echo "BOT ID: $($ret.result.id)"
$msgoffset=0
while (1)
{
    $ret = Invoke-TelegramBotAPI -Method "getUpdates" -Parameters @{ timeout=$timeoutSecs; offset=$msgoffset}
    if (!$ret.ok)
    {
        echo "Error: $ret"
        echo "Waiting 10 seconds to continue"
        Start-Sleep -Seconds 10
        continue;
    }
    ForEach ($msg in $ret.result)
    {
        if ($msg.update_id -ge $offset)
        {
            $msgoffset = $msg.update_id + 1
        }
        $message=$msg.message
        if ($message)
        {
            $fromId=$message.chat.id
            $text=$message.text
            $msgId=$message.message_id
            $fromUser=$message.from.id
            if (!$text)
            {
                continue
            }
            $replymsg = Process-TextReply -MessageText $text -ChatID $fromId -MessageID $msgId -UserID $fromUser
            if ($replymsg)
            {
                Start-Sleep -Seconds 1 #being more similar to a real person
                Send-TelegramMessage -ChatID $fromId -MessageText $replymsg
            }
        }
    }
}
