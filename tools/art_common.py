"""그림 도구들이 같이 쓰는 것 (design.md §3 그림 도구). 혼자 실행하는 도구가 아니다.

- 경로: 저장소 뿌리(ROOT), 프롬프트 data/art/prompts.json (리드 소유, 읽기만)
- load_rgba: 기준 그림을 읽어 배경을 투명하게 만든다.
  프롬프트의 배경은 크로마 초록(#00FF00)이다. 그림 가장자리와 이어진 진한 초록만 배경으로 보고 지운다
  (캐릭터 몸의 초록은 가장자리와 떨어져 있으면 남는다). 이미 투명 배경 PNG면 그대로 쓴다.
- 알파 정리: 16 미만 → 0, 200 이상 → 255 (옅은 점과 반투명 몸통 정리)
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS_PATH = ROOT / "data" / "art" / "prompts.json"

# 초록 정도 = G - max(R, B). HARD보다 크면 배경 후보, 배경 옆에서 SOFT~HARD 사이면 반투명 가장자리.
KEY_HARD = 150
KEY_SOFT = 60
EDGE_PX = 2  # 배경 바로 옆 이만큼은 초록 번짐을 지운다


def setup_console() -> None:
    """한글 출력이 Windows 콘솔에서 깨지지 않게 표준 출력·오류를 UTF-8로."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except AttributeError:
            pass


def wants_help(argv: list[str]) -> bool:
    return "-h" in argv or "--help" in argv


def usage(doc: str, code: int = 0) -> None:
    """사용법(모듈 설명)을 보여 주고 끝낸다. --help는 0, 인자가 틀리면 2."""
    print(doc.strip())
    sys.exit(code)


def load_prompts() -> dict:
    if not PROMPTS_PATH.exists():
        sys.exit(f"프롬프트 파일이 없습니다: {PROMPTS_PATH.relative_to(ROOT).as_posix()}")
    return json.loads(PROMPTS_PATH.read_text(encoding="utf-8"))


def clean_alpha(im):
    """알파 정리 (16 미만 → 0, 200 이상 → 255)."""
    a = im.getchannel("A").point(lambda v: 0 if v < 16 else (255 if v >= 200 else v))
    im.putalpha(a)
    return im


def load_rgba(path: Path):
    """그림을 RGBA로 읽고, 크로마 초록 배경을 투명하게 만든 뒤 알파를 정리한다."""
    import cv2
    import numpy as np
    from PIL import Image

    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    alpha = a[..., 3]
    border = np.concatenate([alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]])
    if (border < 255).mean() < 0.5:  # 가장자리가 대부분 불투명 = 투명 배경이 아님
        rgb = a[..., :3].astype(int)
        green = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
        # 가장자리와 이어진 진한 초록 덩어리만 배경
        _, labels = cv2.connectedComponents((green > KEY_HARD).astype(np.uint8), connectivity=8)
        edge = set(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]).tolist()) - {0}
        bg = np.isin(labels, list(edge))
        # 배경 바로 옆 픽셀: 초록 정도에 따라 반투명, 초록 번짐은 G를 max(R, B)로 눌러 지운다
        kernel = np.ones((2 * EDGE_PX + 1, 2 * EDGE_PX + 1), np.uint8)
        near = (cv2.dilate(bg.astype(np.uint8), kernel) > 0) & ~bg
        soft = near & (green > KEY_SOFT)
        t = np.clip((green - KEY_SOFT) / (KEY_HARD - KEY_SOFT), 0, 1)
        alpha[bg] = 0
        alpha[soft] = (alpha[soft] * (1 - t[soft])).astype(np.uint8)
        spill = near & (green > 0)
        a[..., 1][spill] = np.maximum(a[..., 0], a[..., 2])[spill]
        im = Image.fromarray(a)
    return clean_alpha(im)
