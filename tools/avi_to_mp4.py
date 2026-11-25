"""Converts a Godot Movie Maker AVI (MJPEG) to a small browser-playable MP4 (VP9).

Usage: python tools/avi_to_mp4.py <in.avi> <out.mp4> [--scale=0.75] [--every=1] [--max-seconds=90]
Needs OpenCV (cv2). Godot: godot --path . --write-movie out.avi --fixed-fps 30 ...
"""
import sys

import cv2


def main():
    src, dst = sys.argv[1], sys.argv[2]
    opts = dict(a.split("=", 1) for a in sys.argv[3:] if a.startswith("--") and "=" in a)
    scale = float(opts.get("--scale", "0.75"))
    every = int(opts.get("--every", "1"))
    max_s = float(opts.get("--max-seconds", "120"))
    cap = cv2.VideoCapture(src)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) * scale) // 2 * 2
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) * scale) // 2 * 2
    out = cv2.VideoWriter(dst, cv2.VideoWriter_fourcc(*"vp09"), fps / every, (w, h))
    i = 0
    kept = 0
    while True:
        ok, frame = cap.read()
        if not ok or i / fps > max_s:
            break
        if i % every == 0:
            out.write(cv2.resize(frame, (w, h), interpolation=cv2.INTER_AREA))
            kept += 1
        i += 1
    out.release()
    print("wrote %s: %d frames at %.1f fps, %dx%d" % (dst, kept, fps / every, w, h))


if __name__ == "__main__":
    main()
