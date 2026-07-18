# Produce Freshness Classifier Setup 🍎

The Farms interface requires a produce photo on every new listing. The photo is
scored on-device by `fresh_rotten_fruit_classifier.tflite`, producing a
**Fresh Confidence Score** in [0, 1] that is bucketed into four categories
(thresholds calibrated for a ~25% distribution per band on the validation set —
Red 90 / 25.07%, Orange 90 / 25.07%, Yellow 89 / 24.79%, Green 90 / 25.07%):

| Category | Meaning | Score range |
|----------|---------|-------------|
| 🔴 Red | High Risk | 0.00 – 0.0131 |
| 🟠 Orange | Low Risk | 0.0131 – 0.3116 |
| 🟡 Yellow | Probably Fine | 0.3116 – 0.8753 |
| 🟢 Green | Totally Fresh | 0.8753 – 1.00 |

**Red (High Risk) photos cannot be posted** — the form asks the farmer to
retake the photo or list fresher produce. All other categories post, and the
score badge is shown to restaurants in the Farm Marketplace.

## One-time setup (on your Mac)

The app **builds and runs without any of this** — `FreshnessClassifier.swift`
compiles the TensorFlowLite code only when the pod is present
(`#if canImport(TensorFlowLite)`). Until then, listings post with a
"freshness check unavailable" note instead of a score. To enable real scoring:

### 1. Install the TensorFlowLiteSwift pod

```bash
cd Yard2Yum            # repo root, next to Yard2Yum.xcodeproj and the Podfile
sudo gem install cocoapods   # if you don't have CocoaPods yet
pod install
```

From then on, open **`Yard2Yum.xcworkspace`** (not the `.xcodeproj`) —
CocoaPods generates the workspace, and the existing Firebase Swift-Package
dependencies keep working alongside it.

### 2. Model file — already in the repo ✅

`fresh_rotten_fruit_classifier.tflite` lives in `Yard2Yum/` and is committed
to git. Because the project uses Xcode 16 folder-synchronized groups, the file
is bundled into the app automatically — no drag-into-Xcode step is needed.
Just `git pull` and build.

### 3. Build and run

Post a new listing from the Farm flow ("My Produce" page): pick a photo, watch
the score card appear, and confirm the badge shows up on the listing and in the
restaurant marketplace.

## How the model is run (`FreshnessClassifier.swift`)

- Input: photo resized to the model's input shape (128×128), RGB,
  `Float32` normalized to 0–1 — matching the Python training preprocessing.
- Output: class order `["fresh", "rotten"]`; the fresh probability is the
  Fresh Confidence Score. A single-sigmoid output model is also handled.
- Inference runs off the main thread (`classifyInBackground`).
- If the pod or the bundled model is missing, the classifier is `nil` and the
  UI degrades gracefully.
