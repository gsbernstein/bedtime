"""Compare UI test screenshots against a previous baseline."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


class ScreenshotChange(str, Enum):
    NEW = "new"
    CHANGED = "changed"
    UNCHANGED = "unchanged"
    REMOVED = "removed"


@dataclass(frozen=True)
class ScreenshotComparison:
    name: str
    change: ScreenshotChange
    before_path: Path | None = None
    after_path: Path | None = None
    before_url: str | None = None
    after_url: str | None = None


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _pixel_diff_ratio(left: Path, right: Path) -> float:
    try:
        from PIL import Image, ImageChops
    except ImportError as error:
        raise RuntimeError(
            "Pillow is required for screenshot comparison. Install with: pip install Pillow"
        ) from error

    with Image.open(left) as left_image, Image.open(right) as right_image:
        if left_image.size != right_image.size:
            right_image = right_image.resize(left_image.size)

        left_rgb = left_image.convert("RGB")
        right_rgb = right_image.convert("RGB")
        diff = ImageChops.difference(left_rgb, right_rgb)
        histogram = diff.histogram()
        # RGB histogram: 256 bins per channel
        differing_pixels = sum(
            histogram[index]
            for channel in range(3)
            for index in range(1, 256)
        )
        total_pixels = left_rgb.size[0] * left_rgb.size[1]
        return differing_pixels / (total_pixels * 3)


def screenshots_differ(
    before: Path,
    after: Path,
    *,
    pixel_threshold: float = 0.001,
) -> bool:
    if file_sha256(before) == file_sha256(after):
        return False
    return _pixel_diff_ratio(before, after) > pixel_threshold


def compare_screenshot_sets(
    current_dir: Path,
    baseline_dir: Path | None,
    *,
    baseline_urls: dict[str, str] | None = None,
    pixel_threshold: float = 0.001,
) -> list[ScreenshotComparison]:
    current_paths = {
        path.name: path for path in sorted(current_dir.rglob("*.png")) if path.is_file()
    }
    baseline_paths: dict[str, Path] = {}
    if baseline_dir and baseline_dir.exists():
        baseline_paths = {
            path.name: path for path in sorted(baseline_dir.rglob("*.png")) if path.is_file()
        }

    baseline_urls = baseline_urls or {}
    comparisons: list[ScreenshotComparison] = []

    for name, after_path in current_paths.items():
        before_path = baseline_paths.get(name)
        before_url = baseline_urls.get(name)
        if before_path is None:
            comparisons.append(
                ScreenshotComparison(
                    name=name,
                    change=ScreenshotChange.NEW,
                    after_path=after_path,
                    after_url=None,
                )
            )
            continue

        if screenshots_differ(before_path, after_path, pixel_threshold=pixel_threshold):
            comparisons.append(
                ScreenshotComparison(
                    name=name,
                    change=ScreenshotChange.CHANGED,
                    before_path=before_path,
                    after_path=after_path,
                    before_url=before_url,
                    after_url=None,
                )
            )
        else:
            comparisons.append(
                ScreenshotComparison(
                    name=name,
                    change=ScreenshotChange.UNCHANGED,
                    before_path=before_path,
                    after_path=after_path,
                    before_url=before_url,
                    after_url=before_url,
                )
            )

    for name, before_path in baseline_paths.items():
        if name not in current_paths:
            comparisons.append(
                ScreenshotComparison(
                    name=name,
                    change=ScreenshotChange.REMOVED,
                    before_path=before_path,
                    before_url=baseline_urls.get(name),
                )
            )

    return comparisons
