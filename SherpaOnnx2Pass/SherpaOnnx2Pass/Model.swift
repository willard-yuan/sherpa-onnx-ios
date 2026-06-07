import Foundation

func hasResource(_ forResource: String, _ ofType: String) -> Bool {
  Bundle.main.path(forResource: forResource, ofType: ofType) != nil
}

func getResource(_ forResource: String, _ ofType: String) -> String {
  let path = Bundle.main.path(forResource: forResource, ofType: ofType)
  precondition(
    path != nil,
    "\(forResource).\(ofType) does not exist!\n" + "Remember to change \n"
      + "  Build Phases -> Copy Bundle Resources\n" + "to add it!"
  )
  return path!
}

enum BundledASRModel {
  static let senseVoiceFunASRNanoInt820251217 =
    "sherpa-onnx-sense-voice-funasr-nano-int8-2025-12-17"
}

enum BundledStreamingASRModel {
  static let xASR480msZhEnPunctInt820260605 =
    "sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05"
}

enum BundledVADModel {
  static let silero = "silero_vad"
  static let sileroWindowSize = 512
}

func hasResource(in directory: String, _ forResource: String, _ ofType: String) -> Bool {
  Bundle.main.path(forResource: forResource, ofType: ofType, inDirectory: directory) != nil
    || hasResource(forResource, ofType)
}

func getResource(in directory: String, _ forResource: String, _ ofType: String) -> String {
  if let path = Bundle.main.path(forResource: forResource, ofType: ofType, inDirectory: directory) {
    return path
  }

  return getResource(forResource, ofType)
}

/// Please refer to
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/index.html
/// to download pre-trained models

/// sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20 (Bilingual, Chinese + English)
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/zipformer-transducer-models.html
func getBilingualStreamingZhEnZipformer20230220() -> SherpaOnnxOnlineModelConfig {
  let encoder = getResource("encoder-epoch-99-avg-1.int8", "onnx")
  let decoder = getResource("decoder-epoch-99-avg-1", "onnx")
  let joiner = getResource("joiner-epoch-99-avg-1.int8", "onnx")
  let tokens = getResource("tokens", "txt")

  return sherpaOnnxOnlineModelConfig(
    tokens: tokens,
    transducer: sherpaOnnxOnlineTransducerModelConfig(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner),
    numThreads: 1,
    modelType: "zipformer"
  )
}

/// csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23 (Chinese)
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html#csukuangfj-sherpa-onnx-streaming-zipformer-zh-14m-2023-02-23-chinese

func getStreamingZh14MZipformer20230223() -> SherpaOnnxOnlineModelConfig {
  let encoder = getResource("encoder-epoch-99-avg-1.int8", "onnx")
  let decoder = getResource("decoder-epoch-99-avg-1", "onnx")
  let joiner = getResource("joiner-epoch-99-avg-1.int8", "onnx")
  let tokens = getResource("tokens", "txt")

  return sherpaOnnxOnlineModelConfig(
    tokens: tokens,
    transducer: sherpaOnnxOnlineTransducerModelConfig(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner),
    numThreads: 1,
    modelType: "zipformer"
  )
}

/// csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17 (English)
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html#csukuangfj-sherpa-onnx-streaming-zipformer-en-20m-2023-02-17-english

func getStreamingEn20MZipformer20230217() -> SherpaOnnxOnlineModelConfig {
  let encoder = getResource("encoder-epoch-99-avg-1.int8", "onnx")
  let decoder = getResource("decoder-epoch-99-avg-1", "onnx")
  let joiner = getResource("joiner-epoch-99-avg-1", "onnx")
  let tokens = getResource("tokens", "txt")

  return sherpaOnnxOnlineModelConfig(
    tokens: tokens,
    transducer: sherpaOnnxOnlineTransducerModelConfig(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner),
    numThreads: 1,
    modelType: "zipformer"
  )
}

/// sherpa-onnx-streaming-zipformer-zh-int8-2025-06-30 (Chinese)
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/
func getStreamingZhInt8Zipformer20250630() -> SherpaOnnxOnlineModelConfig {
  let encoder = getResource("encoder.int8", "onnx")
  let decoder = getResource("decoder", "onnx")
  let joiner = getResource("joiner.int8", "onnx")
  let tokens = getResource("tokens", "txt")

  return sherpaOnnxOnlineModelConfig(
    tokens: tokens,
    transducer: sherpaOnnxOnlineTransducerModelConfig(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner),
    numThreads: 1,
    modelType: "zipformer2"
  )
}

/// sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05
/// Streaming Zipformer transducer model with punctuation for Chinese/English.
func hasStreamingXASR480msZhEnPunctInt820260605() -> Bool {
  let directory = BundledStreamingASRModel.xASR480msZhEnPunctInt820260605

  return hasResource(in: directory, "encoder.int8", "onnx")
    && hasResource(in: directory, "decoder", "onnx")
    && hasResource(in: directory, "joiner.int8", "onnx")
    && hasResource(in: directory, "tokens", "txt")
    && hasResource(in: directory, "bpe", "model")
}

func getStreamingXASR480msZhEnPunctInt820260605() -> SherpaOnnxOnlineModelConfig {
  let directory = BundledStreamingASRModel.xASR480msZhEnPunctInt820260605
  let encoder = getResource(in: directory, "encoder.int8", "onnx")
  let decoder = getResource(in: directory, "decoder", "onnx")
  let joiner = getResource(in: directory, "joiner.int8", "onnx")
  let tokens = getResource(in: directory, "tokens", "txt")
  let bpe = getResource(in: directory, "bpe", "model")

  return sherpaOnnxOnlineModelConfig(
    tokens: tokens,
    transducer: sherpaOnnxOnlineTransducerModelConfig(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner),
    numThreads: 2,
    modelType: "zipformer2",
    modelingUnit: "bpe",
    bpeVocab: bpe
  )
}

/// ========================================
///   Non-streaming models
/// ========================================

/// csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14 (Chinese)
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-paraformer/paraformer-models.html#csukuangfj-sherpa-onnx-paraformer-zh-2023-09-14-chinese
func getNonStreamingZhParaformer20230914() -> SherpaOnnxOfflineModelConfig {
  let model = getResource("model.int8", "onnx")
  let tokens = getResource("paraformer-tokens", "txt")

  return sherpaOnnxOfflineModelConfig(
    tokens: tokens,
    paraformer: sherpaOnnxOfflineParaformerModelConfig(
      model: model),
    numThreads: 1,
    modelType: "paraformer"
  )
}

// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/whisper/tiny.en.html#tiny-en
// English, int8 encoder and decoder
func getNonStreamingWhisperTinyEn() -> SherpaOnnxOfflineModelConfig {
  let encoder = getResource("tiny.en-encoder.int8", "onnx")
  let decoder = getResource("tiny.en-decoder.int8", "onnx")
  let tokens = getResource("tiny.en-tokens", "txt")

  return sherpaOnnxOfflineModelConfig(
    tokens: tokens,
    whisper: sherpaOnnxOfflineWhisperModelConfig(
      encoder: encoder,
      decoder: decoder
    ),
    numThreads: 1,
    modelType: "whisper"
  )
}

// icefall-asr-multidataset-pruned_transducer_stateless7-2023-05-04 (English)
// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/zipformer-transducer-models.html#icefall-asr-multidataset-pruned-transducer-stateless7-2023-05-04-english

func getNonStreamingEnZipformer20230504() -> SherpaOnnxOfflineModelConfig {
  let encoder = getResource("encoder-epoch-30-avg-4.int8", "onnx")
  let decoder = getResource("decoder-epoch-30-avg-4", "onnx")
  let joiner = getResource("joiner-epoch-30-avg-4", "onnx")
  let tokens = getResource("non-streaming-zipformer-tokens", "txt")

  return sherpaOnnxOfflineModelConfig(
    tokens: tokens,
    transducer: sherpaOnnxOfflineTransducerModelConfig(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner),
    numThreads: 1,
    modelType: "zipformer"
  )
}

/// sherpa-onnx-sense-voice-funasr-nano-int8-2025-12-17
/// Non-streaming SenseVoice CTC model converted from Fun-ASR-Nano.
func hasNonStreamingSenseVoiceFunASRNanoInt820251217() -> Bool {
  let directory = BundledASRModel.senseVoiceFunASRNanoInt820251217

  return hasResource(in: directory, "model.int8", "onnx")
    && hasResource(in: directory, "tokens", "txt")
}

func getNonStreamingSenseVoiceFunASRNanoInt820251217(
  language: String = "",
  useInverseTextNormalization: Bool = true
) -> SherpaOnnxOfflineModelConfig {
  let directory = BundledASRModel.senseVoiceFunASRNanoInt820251217
  let model = getResource(in: directory, "model.int8", "onnx")
  let tokens = getResource(in: directory, "tokens", "txt")
  let senseVoice = sherpaOnnxOfflineSenseVoiceModelConfig(
    model: model,
    language: language,
    useInverseTextNormalization: useInverseTextNormalization
  )

  return sherpaOnnxOfflineModelConfig(
    tokens: tokens,
    numThreads: 2,
    senseVoice: senseVoice
  )
}

func hasSileroVadModel() -> Bool {
  hasResource(BundledVADModel.silero, "onnx")
}

func getSileroVadModelConfig(sampleRate: Int = 16000) -> SherpaOnnxVadModelConfig {
  let model = getResource(BundledVADModel.silero, "onnx")
  let sileroVad = sherpaOnnxSileroVadModelConfig(
    model: model,
    threshold: 0.15,
    minSilenceDuration: 0.35,
    minSpeechDuration: 0.1,
    windowSize: BundledVADModel.sileroWindowSize,
    maxSpeechDuration: 10.0
  )

  return sherpaOnnxVadModelConfig(
    sileroVad: sileroVad,
    sampleRate: Int32(sampleRate),
    numThreads: 1
  )
}

/// Please refer to
/// https://k2-fsa.github.io/sherpa/onnx/pretrained_models/index.html
/// to add more models if you need
