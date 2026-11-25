"""Puts a "before" and an "after" screenshot side by side with labels (for PR and preview media).

Usage: python tools/compose_before_after.py <before.png> <after.png> <out.png> [caption]
Needs OpenCV (cv2) and numpy.
"""
import sys

import cv2
import numpy as np


def label(img, text, colour):
    out = img.copy()
    cv2.rectangle(out, (0, 0), (out.shape[1], 34), (15, 17, 21), -1)
    cv2.putText(out, text, (12, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, colour, 2, cv2.LINE_AA)
    return out


def main():
    before = cv2.imread(sys.argv[1])
    after = cv2.imread(sys.argv[2])
    h = min(before.shape[0], after.shape[0])
    before = cv2.resize(before, (int(before.shape[1] * h / before.shape[0]), h))
    after = cv2.resize(after, (int(after.shape[1] * h / after.shape[0]), h))
    gap = np.full((h, 12, 3), 40, np.uint8)
    row = np.hstack([label(before, "BEFORE (main)", (160, 170, 180)), gap, label(after, "AFTER (M1)", (32, 176, 255))])
    if len(sys.argv) > 4:
        cap = np.full((40, row.shape[1], 3), 21, np.uint8)
        cv2.putText(cap, sys.argv[4], (12, 27), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (232, 234, 237), 1, cv2.LINE_AA)
        row = np.vstack([row, cap])
    cv2.imwrite(sys.argv[3], row)


if __name__ == "__main__":
    main()
