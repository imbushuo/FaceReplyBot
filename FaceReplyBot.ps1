$BotToken = "156154272:AAFTmKaVhpaqz59yQ8l2lhamMR9mdvs38KE"; #This token has been revoked.
$timeoutSecs = 20
$replyMap = @{ "🌚"="🌝"; "🌝"="🌚"; "→_→"="←_←"; "←_←"="→_→"; "#NSFW"="噫"}
$global:lastReplyTimes=@{}

Function sendRequest([string] $method,[hashtable]$params=@{})
{
    return Invoke-RestMethod "https://api.telegram.org/bot$BotToken/$method" -Body $params -Method Post -TimeoutSec 50
}

Function sendMessage($chatid, $msgtext, $replyto)
{
    sendRequest "sendMessage" @{chat_id=$chatid; text=$msgtext; reply_to_message_id=$replyto}
}

Function processReply($msgtext,$chatId)
{
    if ($msgtext -and $replyMap.ContainsKey($msgtext))
    {
        if ($chatId -lt 0)
        {
            if ($global:lastReplyTimes.ContainsKey($chatId))
            {
                $span = [DateTime]::Now-$global:lastReplyTimes[$chatId];
                if ($span.TotalSeconds -lt 20)
                {
                    return
                }
                $global:lastReplyTimes[$chatId]=[DateTime]::Now
            }
            else
            {
                $global:lastReplyTimes.Add($chatId,[DateTime]::Now)
            }
        }
    
        $ret = $replyMap[$msgtext]
        return $ret
    }
}

$ret = sendRequest "getMe" 
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
    $ret = sendRequest "getUpdates" @{ timeout=$timeoutSecs; offset=$msgoffset}
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
            $replymsg = processReply $text $fromId
            if ($replymsg)
            {
                sendMessage $fromId $replymsg
            }
        }
    }
}
