#!/bin/bash

# Function to convert HH:MM:SS to seconds
convert_to_seconds() {
    if [[ -z "$1" ]]; then
        echo ""
        return
    fi

    if [[ $1 =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        hours=${BASH_REMATCH[1]}
        minutes=${BASH_REMATCH[2]}
        seconds=${BASH_REMATCH[3]}

        total_seconds=$((hours * 3600 + minutes * 60 + seconds))
        echo "$total_seconds"
    else
        echo "Invalid time format. Please use HH:MM:SS"
        exit 1
    fi
}

# Function to extract YouTube video ID from URL or return the ID if already provided
extract_video_id() {
    local input=$1
    if [[ $input =~ ^https?://(www\.)?youtube\.com/watch\?v=([^&]+) ]]; then
        echo "${BASH_REMATCH[2]}"
    elif [[ $input =~ ^https?://youtu\.be/([^?]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$input"
    fi
}

# Ask for YouTube video ID or URL
read -p "Enter YouTube video ID or URL: " input

if [[ -z "$input" ]]; then
    echo "Video ID or URL is required"
    exit 1
fi

# Extract video ID from input
video_id=$(extract_video_id "$input")

if [[ ! "$video_id" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
    echo "Invalid YouTube video ID or URL"
    exit 1
fi

# Ask for start time (optional)
read -p "Enter start time (HH:MM:SS) [optional]: " start_time
start_seconds=$(convert_to_seconds "$start_time")

# Ask for end time (optional)
read -p "Enter end time (HH:MM:SS) [optional]: " end_time
end_seconds=$(convert_to_seconds "$end_time")

# Ask for media type preference
read -p "Do you want video or just audio? (v/a): " media_type

# Validate input
while [[ ! "$media_type" =~ ^[va]$ ]]; do
    read -p "Please enter 'v' for video or 'a' for audio: " media_type
done

# Construct yt-dlp command
cmd="yt-dlp -vU "

# Add media type option
if [[ "$media_type" == "a" ]]; then
    cmd+="-f bestaudio"
else
    cmd+="-f (bestvideo[height<=1080][ext=mp4]/bestvideo)+bestaudio/best"
    cmd+=" --merge-output-format mp4 "
fi

echo $cmd

# Add video ID
cmd+=" https://www.youtube.com/watch?v=$video_id"

temp_file="./yt-dlp-temp.mp4"

cmd+=" -o $temp_file"

if ! $cmd; then
    echo "Error: Failed to download video."
    exit 1
fi

if [[ ! -s "$temp_file" ]]; then
    echo "Error: Downloaded file is empty."
    exit 1
fi

# Process the temporary file with ffmpeg
ffmpeg_cmd="ffmpeg -v verbose -i $temp_file"

if [[ -n "$start_seconds" ]]; then
    ffmpeg_cmd+=" -ss $start_seconds"
fi

if [[ -n "$end_seconds" ]]; then
    ffmpeg_cmd+=" -to $end_seconds"
fi

if [[ "$media_type" == "a" ]]; then
    ffmpeg_cmd+=" -y -c:a libmp3lame output_audio.mp3"
else
    ffmpeg_cmd+=" -c:v libx264 -c:a aac output_video.mp4"
fi

$ffmpeg_cmd

rm "$temp_file"