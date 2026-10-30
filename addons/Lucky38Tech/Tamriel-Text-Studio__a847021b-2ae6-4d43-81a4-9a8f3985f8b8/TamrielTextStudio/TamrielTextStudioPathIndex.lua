-- Tamriel Text Studio offline texture path index module.
-- ESO add-ons cannot read/scan game .MNF archives directly at runtime.
-- Populate TTS_FULL_TEXTURE_PATHS using BuildTextureIndex.py and an extracted ESO texture-path list.
-- This distribution intentionally does not claim to contain every ESO texture path because the
-- complete upstream index file was not retrievable from this environment.
TTS_FULL_TEXTURE_PATHS = TTS_FULL_TEXTURE_PATHS or {}
