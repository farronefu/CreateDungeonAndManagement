# 画面改修 v0.2

2026-09-13。ユーザー提供の「プレイ画像.jpg」「画面説明.jpg」を画面構成の参考として使用。画像内の注釈をゲーム内UIへ取り込む指示とは扱わず、原作画像も製品素材へ転用していない。

- 上部136px：操作対象外の独自地上風景。地下深度が変わっても表示する。
- 地下：960×400px、40pxのタイルで24×10マスを表示。60×40マスの全体を縮小しない。
- 下部64px：「掘」「軍」、生物数、選択土の養分・魔分、カメラ深度、操作案内。
- 20pxで描き直した土・生物を2倍で描画。苔・結晶、壁際の影、巣、ツルハシ形状のカーソルを追加。
- 勇者は茶色の斧戦士と紫の魔法使い。HPは地上側のコンパクトな枠に表示。
- 入力、生態系、数値、勝敗、時間停止ルールは維持。描画を`garden_view.gd`へ分離。

## 素材

`assets/terrain-v2.png`と`assets/actors-v2.png`は、編集可能なコードによるピクセルアトラス。生成元は`tools/build_pixel_art.py`（Python、Pillow）。生物は4コマの簡易アニメーションで、動作別の完全なアニメーションではない。

`assets/surface-v2.png`は組み込み`image_gen`による独自背景。CLI/APIフォールバックは使用していない。元画像を改変せずにプロジェクトへコピーし、ゲームでは縦横比を保った描画領域の切り出しで横長の帯に配置する。今回の参考画像の建物や地形をそのまま複製していない。

### 背景の生成プロンプト

```text
Create a production-ready background asset for a Japanese 2D pixel-art dungeon-defense game. This is ORIGINAL artwork, not a screenshot and no UI. Extremely wide panoramic banner, aspect ratio 7:1, intended displayed at 960 x 136 pixels. Crisp hand-placed pixel-art aesthetic, coherent 16-bit pixel clusters, warm muted earth and amber highlights against a luminous pale teal sky, layered distant blue-green mountain silhouettes, dark fir forests, ruined stone watchtower on the far left, a small timber-roofed abandoned mill and wind vane on the far right, irregular grass and earthy ledge along the bottom. The middle third should be an open grassy clearing (the game will render a dungeon entrance over this), keep it low and uncluttered. Thin wisps of cloud, atmospheric depth, carefully shaded masonry, moss, tufts of grass, tiny wildflowers, understated golden late afternoon light. Side view landscape, horizon and ground perfectly horizontal, a richly crafted game environment. No characters, no text, no logos, no cave entrance or doorway in the center, no underground section, no grid, no frame. Fill the whole panoramic image. Deliver a very wide horizontal image.
```

## 見た目の確認

Godotで実際に描画したタイトル・育成・配置・戦闘・ポーズ・勝敗の画像を`docs/images/`へ保存。深度とカメラ対象をHUDで区別し、マップの端がHUDや背景へはみ出さないよう確認する。
