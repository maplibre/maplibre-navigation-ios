import AVFoundation
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigationObjC

extension ErrorUserInfoKey {
    static let spokenInstructionErrorCode = MBSpokenInstructionErrorCodeKey
}

public extension NSAttributedString {
    @available(iOS 10.0, *)
    func pronounced(_ pronunciation: String) -> NSAttributedString {
        let phoneticWords = pronunciation.components(separatedBy: " ")
        let phoneticString = NSMutableAttributedString()
        for (word, phoneticWord) in zip(string.components(separatedBy: " "), phoneticWords) {
            // AVSpeechSynthesizer doesn’t recognize some common IPA symbols.
            let phoneticWord = phoneticWord.byReplacing([("ɡ", "g"), ("ɹ", "r")])
            if phoneticString.length > 0 {
                phoneticString.append(NSAttributedString(string: " "))
            }
            phoneticString.append(NSAttributedString(string: word, attributes: [
                NSAttributedString.Key(rawValue: AVSpeechSynthesisIPANotationAttribute): phoneticWord
            ]))
        }
        return phoneticString
    }
}

extension SpokenInstruction {
    @available(iOS 10.0, *)
    func attributedText(for legProgress: RouteLegProgress) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        if let step = legProgress.upComingStep,
           let name = step.names?.first,
           let phoneticName = step.phoneticNames?.first {
            let nameRange = attributedText.mutableString.range(of: name)
            if nameRange.location != NSNotFound {
                attributedText.replaceCharacters(in: nameRange, with: NSAttributedString(string: name).pronounced(phoneticName))
            }
        }
        if let step = legProgress.followOnStep,
           let name = step.names?.first,
           let phoneticName = step.phoneticNames?.first {
            let nameRange = attributedText.mutableString.range(of: name)
            if nameRange.location != NSNotFound {
                attributedText.replaceCharacters(in: nameRange, with: NSAttributedString(string: name).pronounced(phoneticName))
            }
        }
        return attributedText
    }
}

/**
 The `RouteVoiceController` class provides voice guidance.
 */
@objc(MBRouteVoiceController)
open class RouteVoiceController: NSObject, AVSpeechSynthesizerDelegate {
    lazy var speechSynth = AVSpeechSynthesizer()
    
    let audioQueue = DispatchQueue(label: Bundle.mapboxNavigation.bundleIdentifier! + ".audio")
    
    /**
     If true, a noise indicating the user is going to be rerouted will play prior to rerouting.
     */
    @objc public var playRerouteSound = true
    
    /**
     Sound to play prior to reroute. Inherits volume level from `volume`.
     */
    @objc public var rerouteSoundPlayer: AVAudioPlayer = try! AVAudioPlayer(data: NSDataAsset(name: "reroute-sound", bundle: .mapboxNavigation)!.data, fileTypeHint: AVFileType.mp3.rawValue)
    
    /**
     Delegate used for getting metadata information about a particular spoken instruction.
     */
    public weak var voiceControllerDelegate: VoiceControllerDelegate?
    
    var lastSpokenInstruction: SpokenInstruction?
    var routeProgress: RouteProgress?
    
    var volumeToken: NSKeyValueObservation?
    var muteToken: NSKeyValueObservation?
    
    /**
     Default initializer for `RouteVoiceController`.
     */
    override public init() {
        super.init()

        self.speechSynth.delegate = self
        
        self.resumeNotifications()
    }

    private func verifyBackgroundAudio() {
        guard UIApplication.shared.isKind(of: UIApplication.self) else {
            return
        }

        if !Bundle.main.backgroundModes.contains("audio") {
            assertionFailure("This application’s Info.plist file must include “audio” in UIBackgroundModes. This background mode is used for spoken instructions while the application is in the background.")
        }
    }

    deinit {
        suspendNotifications()
        speechSynth.stopSpeaking(at: .immediate)
    }
    
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.didPassSpokenInstructionPoint(notification:)), name: .routeControllerDidPassSpokenInstructionPoint, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.pauseSpeechAndPlayReroutingDing(notification:)), name: .routeControllerWillReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didReroute(notification:)), name: .routeControllerDidReroute, object: nil)
        
        self.muteToken = NavigationSettings.shared.observe(\.voiceMuted) { [weak self] settings, _ in
            if settings.voiceMuted {
                self?.speechSynth.stopSpeaking(at: .immediate)
            }
        }
    }
    
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassSpokenInstructionPoint, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerWillReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
    }
    
    @objc func didReroute(notification: NSNotification) {
        // Play reroute sound when a faster route is found
        if notification.userInfo?[RouteControllerNotificationUserInfoKey.isProactiveKey] as! Bool {
            self.pauseSpeechAndPlayReroutingDing(notification: notification)
        }
    }
    
    @objc func pauseSpeechAndPlayReroutingDing(notification: NSNotification) {
        self.speechSynth.stopSpeaking(at: .word)
        
        guard self.playRerouteSound, !NavigationSettings.shared.voiceMuted else {
            return
        }
        
        do {
            try self.mixAudio()
        } catch {
            self.voiceControllerDelegate?.voiceController?(self, spokenInstructionsDidFailWith: error)
        }
        self.rerouteSoundPlayer.play()
    }
    
    @objc public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        do {
            try self.unDuckAudio()
        } catch {
            self.voiceControllerDelegate?.voiceController?(self, spokenInstructionsDidFailWith: error)
        }
    }
    
    func duckAudio() throws {
        let categoryOptions: AVAudioSession.CategoryOptions = [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.spokenAudio)
        try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: categoryOptions)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    func mixAudio() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    func unDuckAudio() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
    
    @objc open func didPassSpokenInstructionPoint(notification: NSNotification) {
        guard !NavigationSettings.shared.voiceMuted else { return }
        
        self.routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
        assert(self.routeProgress != nil, "routeProgress should not be nil.")

        guard let instruction = routeProgress?.currentLegProgress.currentStepProgress.currentSpokenInstruction else { return }
        let speechLocale = self.routeProgress?.route.routeOptions.locale
        
        self.lastSpokenInstruction = instruction
        self.speak(instruction, with: speechLocale)
    }

    /**
     Reads aloud the given instruction.
     
     - parameter instruction: The instruction to read aloud.
     - parameter locale: The `Locale` used to create the voice read aloud the given instruction. If `nil` the `Locale.preferredLocalLanguageCountryCode` is used for creating the voice.
     - parameter ignoreProgress: A `Bool` that indicates if the routeProgress is added to the instruction.
     */
    open func speak(_ instruction: SpokenInstruction, with locale: Locale?, ignoreProgress: Bool = false) {
        // Don't require background audio unless the implementer is actually using speech APIs
        self.verifyBackgroundAudio()

        if self.speechSynth.isSpeaking, let lastSpokenInstruction {
            self.voiceControllerDelegate?.voiceController?(self, didInterrupt: lastSpokenInstruction, with: instruction)
        }
        
        do {
            try self.duckAudio()
        } catch {
            self.voiceControllerDelegate?.voiceController?(self, spokenInstructionsDidFailWith: error)
        }
        
        let modifiedInstruction = self.voiceControllerDelegate?.voiceController?(self, willSpeak: instruction, routeProgress: self.routeProgress) ?? instruction

        let utterance: AVSpeechUtterance

        if locale?.identifier == "en-US" {
            // Alex can’t handle attributed text.
            utterance = AVSpeechUtterance(string: modifiedInstruction.text)
            utterance.voice = AVSpeechSynthesisVoice(identifier: AVSpeechSynthesisVoiceIdentifierAlex)
        } else {
            if !ignoreProgress, let routeProgress {
                utterance = AVSpeechUtterance(attributedString: modifiedInstruction.attributedText(for: routeProgress.currentLegProgress))
            } else {
                utterance = AVSpeechUtterance(string: modifiedInstruction.text)
            }
            
            // Only localized languages will have a proper fallback voice
            utterance.voice = AVSpeechSynthesisVoice(language: locale?.identifier ?? Locale.preferredLocalLanguageCountryCode)
        }
        
        self.speechSynth.speak(utterance)
    }
}

/**
 The `VoiceControllerDelegate` protocol defines methods that allow an object to respond to significant events related to spoken instructions.
 */
@objc(MBVoiceControllerDelegate)
public protocol VoiceControllerDelegate {
    /**
     Called when the voice controller failed to speak an instruction.
     
     - parameter voiceController: The voice controller that experienced the failure.
     - parameter error: An error explaining the failure and its cause. The `MBSpokenInstructionErrorCodeKey` key of the error’s user info dictionary is a `SpokenInstructionErrorCode` indicating the cause of the failure.
     */
    @objc(voiceController:spokenInstrucionsDidFailWithError:)
    optional func voiceController(_ voiceController: RouteVoiceController, spokenInstructionsDidFailWith error: Error)
    
    /**
     Called when one spoken instruction interrupts another instruction currently being spoken.
     
     - parameter voiceController: The voice controller that experienced the interruption.
     - parameter interruptedInstruction: The spoken instruction currently in progress that has been interrupted.
     - parameter interruptingInstruction: The spoken instruction that is interrupting the current instruction.
     */
    @objc(voiceController:didInterruptSpokenInstruction:withInstruction:)
    optional func voiceController(_ voiceController: RouteVoiceController, didInterrupt interruptedInstruction: SpokenInstruction, with interruptingInstruction: SpokenInstruction)
    
    /** Called when a spoken is about to speak. Useful if it is necessary to give a custom instruction instead. Noting, changing the `distanceAlongStep` property on `SpokenInstruction` will have no impact on when the instruction will be said.
     
     - parameter voiceController: The voice controller that will speak an instruction.
     - parameter instruction: The spoken instruction that will be said.
     - parameter routeProgress: The `RouteProgress` just before when the instruction is scheduled to be spoken. Could be `nil` if no progress is available or if it should be ignored.
     **/
    @objc(voiceController:willSpeakSpokenInstruction:routeProgress:)
    optional func voiceController(_ voiceController: RouteVoiceController, willSpeak instruction: SpokenInstruction, routeProgress: RouteProgress?) -> SpokenInstruction?
}
