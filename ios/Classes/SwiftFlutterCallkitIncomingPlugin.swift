import Flutter
import UIKit
import CallKit
import AVFoundation

@available(iOS 10.0, *)
public class SwiftFlutterCallkitIncomingPlugin: NSObject, FlutterPlugin, CXProviderDelegate {
	
	static let ACTION_DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP = "com.hiennv.flutter_callkit_incoming.DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP"
	
	static let ACTION_CALL_INCOMING = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_INCOMING"
	static let ACTION_CALL_START = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_START"
	static let ACTION_CALL_ACCEPT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"
	static let ACTION_CALL_DECLINE = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_DECLINE"
	static let ACTION_CALL_ENDED = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED"
	static let ACTION_CALL_TIMEOUT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TIMEOUT"
	static let ACTION_CALL_CUSTOM = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_CUSTOM"
	
	static let ACTION_CALL_TOGGLE_HOLD = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_HOLD"
	static let ACTION_CALL_TOGGLE_MUTE = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_MUTE"
	static let ACTION_CALL_TOGGLE_DMTF = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_DMTF"
	static let ACTION_CALL_TOGGLE_GROUP = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_GROUP"
	static let ACTION_CALL_TOGGLE_AUDIO_SESSION = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_AUDIO_SESSION"
	
	@objc public private(set) static var sharedInstance: SwiftFlutterCallkitIncomingPlugin!
	
	private var streamHandlers: WeakArray<EventCallbackHandler> = WeakArray([])
	
	private var callManager: CallManager
	
	private var sharedProvider: CXProvider? = nil
	
	private var outgoingCall : Call?
	private var answerCall : Call?
	
	private var data: Data?
	private var isFromPushKit: Bool = false
	private var silenceEvents: Bool = false
	private let devicePushTokenVoIP = "DevicePushTokenVoIP"
	
	
	private func sendEvent(_ event: String, _ body: [String : Any?]?) {
		if silenceEvents {
			print(event, " silenced")
			return
		} else {
			streamHandlers.reap().forEach { handler in
				handler?.send(event, body ?? [:])
			}
		}
		
	}
	
	@objc public func sendEventCustom(_ event: String, body: NSDictionary?) {
		streamHandlers.reap().forEach { handler in
			handler?.send(event, body ?? [:])
		}
	}
	
	public static func sharePluginWithRegister(with registrar: FlutterPluginRegistrar) {
		if(sharedInstance == nil){
			sharedInstance = SwiftFlutterCallkitIncomingPlugin(messenger: registrar.messenger())
		}
		sharedInstance.shareHandlers(with: registrar)
	}
	
	public static func register(with registrar: FlutterPluginRegistrar) {
		sharePluginWithRegister(with: registrar)
	}
	
	private static func createMethodChannel(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
		return FlutterMethodChannel(name: "flutter_callkit_incoming", binaryMessenger: messenger)
	}
	
	private static func createEventChannel(messenger: FlutterBinaryMessenger) -> FlutterEventChannel {
		return FlutterEventChannel(name: "flutter_callkit_incoming_events", binaryMessenger: messenger)
	}
	
	public init(messenger: FlutterBinaryMessenger) {
		callManager = CallManager()
	}
	
	private func shareHandlers(with registrar: FlutterPluginRegistrar) {
		registrar.addMethodCallDelegate(self, channel: Self.createMethodChannel(messenger: registrar.messenger()))
		let eventsHandler = EventCallbackHandler()
		self.streamHandlers.append(eventsHandler)
		Self.createEventChannel(messenger: registrar.messenger()).setStreamHandler(eventsHandler)
	}
	
	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
		switch call.method {
		case "showCallkitIncoming":
			guard let args = call.arguments else {
				result("OK")
				return
			}
			if let getArgs = args as? [String: Any] {
				self.data = Data(args: getArgs)
				showCallkitIncoming(self.data!, fromPushKit: false)
			}
			result("OK")
			break
		case "showMissCallNotification":
			result("OK")
			break
		case "startCall":
			guard let args = call.arguments else {
				result("OK")
				return
			}
			if let getArgs = args as? [String: Any] {
				self.data = Data(args: getArgs)
				self.startCall(self.data!, fromPushKit: false)
			}
			result("OK")
			break
		case "endCall":
			guard let args = call.arguments else {
				result("OK")
				return
			}
			if(self.isFromPushKit){
				self.endCall(self.data!)
			}else{
				if let getArgs = args as? [String: Any] {
					self.data = Data(args: getArgs)
					self.endCall(self.data!)
				}
			}
			result("OK")
			break
		case "muteCall":
			guard let args = call.arguments as? [String: Any] ,
				  let callId = args["id"] as? String,
				  let isMuted = args["isMuted"] as? Bool else {
				result("OK")
				return
			}
			
			self.muteCall(callId, isMuted: isMuted)
			result("OK")
			break
		case "isMuted":
			guard let args = call.arguments as? [String: Any] ,
				  let callId = args["id"] as? String else{
				result(false)
				return
			}
			guard let callUUID = UUID(uuidString: callId),
				  let call = self.callManager.callWithUUID(uuid: callUUID) else {
				result(false)
				return
			}
			result(call.isMuted)
			break
		case "holdCall":
			guard let args = call.arguments as? [String: Any] ,
				  let callId = args["id"] as? String,
				  let onHold = args["isOnHold"] as? Bool else {
				result("OK")
				return
			}
			self.holdCall(callId, onHold: onHold)
			result("OK")
			break
		case "callConnected":
			guard let args = call.arguments else {
				result("OK")
				return
			}
			if(self.isFromPushKit){
				self.connectedCall(self.data!)
			}else{
				if let getArgs = args as? [String: Any] {
					self.data = Data(args: getArgs)
					self.connectedCall(self.data!)
				}
			}
			result("OK")
			break
		case "activeCalls":
			result(self.callManager.activeCalls())
			break;
		case "endAllCalls":
			self.callManager.endCallAlls()
			result("OK")
			break
		case "getDevicePushTokenVoIP":
			result(self.getDevicePushTokenVoIP())
			break;
		case "silenceEvents":
			guard let silence = call.arguments as? Bool else {
				result("OK")
				return
			}
			
			self.silenceEvents = silence
			result("OK")
			break;
		case "requestNotificationPermission":
			result("OK")
			break
		case "requestFullIntentPermission":
			result("OK")
			break
		case "canUseFullScreenIntent":
			result(true)
			break
		case "hideCallkitIncoming":
			result("OK")
			break
		case "endNativeSubsystemOnly":
			result("OK")
			break
		case "setAudioRoute":
			result("OK")
			break
		default:
			result(FlutterMethodNotImplemented)
		}
	}
	
	@objc public func setDevicePushTokenVoIP(_ deviceToken: String) {
		UserDefaults.standard.set(deviceToken, forKey: devicePushTokenVoIP)
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP, ["deviceTokenVoIP":deviceToken])
	}
	
	@objc public func getDevicePushTokenVoIP() -> String {
		return UserDefaults.standard.string(forKey: devicePushTokenVoIP) ?? ""
	}
	
	@objc public func getAcceptedCall() -> Data? {
		NSLog("Call data ids \(String(describing: data?.uuid)) \(String(describing: answerCall?.uuid.uuidString))")
		if data?.uuid.lowercased() == answerCall?.uuid.uuidString.lowercased() {
			return data
		}
		return nil
	}
	
	@objc public func showCallkitIncoming(_ data: Data, fromPushKit: Bool) {
		self.isFromPushKit = fromPushKit
		if(fromPushKit){
			self.data = data
		}
		
			// Add this print statement:
		print("CallkitIncoming: Dart data.type = \(data.type)")
		print("CallkitIncoming: Dart data.supportsVideo = \(data.supportsVideo)")
		
		var handle: CXHandle?
		handle = CXHandle(type: self.getHandleType(data.handleType), value: data.getEncryptHandle())
		
		let callUpdate = CXCallUpdate()
		callUpdate.remoteHandle = handle
		callUpdate.supportsDTMF = data.supportsDTMF
		callUpdate.supportsHolding = data.supportsHolding
		callUpdate.supportsGrouping = data.supportsGrouping
		callUpdate.supportsUngrouping = data.supportsUngrouping
		callUpdate.hasVideo = data.type > 0 ? true : false
		
			// Add this print statement:
		print("CallkitIncoming: CXCallUpdate.hasVideo set to: \(callUpdate.hasVideo)")
		
		
		initCallkitProvider(data) // This uses data.supportsVideo internally.
		
			// Add this print statement to verify the provider configuration
		if let config = self.sharedProvider?.configuration {
			print("CallkitIncoming: CXProviderConfiguration.supportsVideo set to: \(config.supportsVideo)")
		}
		
		
		let uuid = UUID(uuidString: data.uuid)
		
		configurAudioSession()
		self.sharedProvider?.reportNewIncomingCall(with: uuid!, update: callUpdate) { error in
			if(error == nil) {
				self.configurAudioSession()
				let call = Call(uuid: uuid!, data: data)
				call.handle = data.handle
				self.callManager.addCall(call)
				self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_INCOMING, data.toJSON())
				self.endCallNotExist(data)
			} else {
				print("CallkitIncoming: Error reporting new incoming call: \(error?.localizedDescription ?? "unknown error")")
			}
		}
	}
	
	@objc public func startCall(_ data: Data, fromPushKit: Bool) {
		self.isFromPushKit = fromPushKit
		if(fromPushKit){
			self.data = data
		}
		initCallkitProvider(data)
		self.callManager.startCall(data)
	}
	
	@objc public func muteCall(_ callId: String, isMuted: Bool) {
		guard let callId = UUID(uuidString: callId),
			  let call = self.callManager.callWithUUID(uuid: callId) else {
			return
		}
		if call.isMuted == isMuted {
			self.sendMuteEvent(callId.uuidString, isMuted)
		} else {
			self.callManager.muteCall(call: call, isMuted: isMuted)
		}
	}
	
	@objc public func holdCall(_ callId: String, onHold: Bool) {
		guard let callId = UUID(uuidString: callId),
			  let call = self.callManager.callWithUUID(uuid: callId) else {
			return
		}
		if call.isOnHold == onHold {
			self.sendMuteEvent(callId.uuidString,  onHold)
		} else {
			self.callManager.holdCall(call: call, onHold: onHold)
		}
	}
	
	@objc public func endCall(_ data: Data) {
		var call: Call? = nil
		if(self.isFromPushKit){
			call = Call(uuid: UUID(uuidString: self.data!.uuid)!, data: data)
			self.isFromPushKit = false
			self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, data.toJSON())
		}else {
			call = Call(uuid: UUID(uuidString: data.uuid)!, data: data)
		}
		self.callManager.endCall(call: call!)
	}
	
	@objc public func connectedCall(_ data: Data) {
		var call: Call? = nil
		if(self.isFromPushKit){
			call = Call(uuid: UUID(uuidString: self.data!.uuid)!, data: data)
			self.isFromPushKit = false
		}else {
			call = Call(uuid: UUID(uuidString: data.uuid)!, data: data)
		}
		self.callManager.connectedCall(call: call!)
	}
	
	@objc public func activeCalls() -> [[String: Any]] {
		return self.callManager.activeCalls()
	}
	
	@objc public func endAllCalls() {
		self.isFromPushKit = false
		self.callManager.endCallAlls()
	}
	
	@objc public func getDevicePushTokenVoIP() -> String {
		return UserDefaults.standard.string(forKey: devicePushTokenVoIP) ?? ""
	}
	
	@objc public func getAcceptedCall() -> Data? {
		NSLog("Call data ids \(String(describing: data?.uuid)) \(String(describing: answerCall?.uuid.uuidString))")
		if data?.uuid.lowercased() == answerCall?.uuid.uuidString.lowercased() {
			return data
		}
		return nil
	}
	
	@objc public func showCallkitIncoming(_ data: Data, fromPushKit: Bool) {
		self.isFromPushKit = fromPushKit
		if(fromPushKit){
			self.data = data
		}
		
			// Add this print statement:
		print("CallkitIncoming: Dart data.type = \(data.type)")
		print("CallkitIncoming: Dart data.supportsVideo = \(data.supportsVideo)")
		
		var handle: CXHandle?
		handle = CXHandle(type: self.getHandleType(data.handleType), value: data.getEncryptHandle())
		
		let callUpdate = CXCallUpdate()
		callUpdate.remoteHandle = handle
		callUpdate.supportsDTMF = data.supportsDTMF
		callUpdate.supportsHolding = data.supportsHolding
		callUpdate.supportsGrouping = data.supportsGrouping
		callUpdate.supportsUngrouping = data.supportsUngrouping
		callUpdate.hasVideo = data.type > 0 ? true : false
		
			// Add this print statement:
		print("CallkitIncoming: CXCallUpdate.hasVideo set to: \(callUpdate.hasVideo)")
		
		
		initCallkitProvider(data) // This uses data.supportsVideo internally.
		
			// Add this print statement to verify the provider configuration
		if let config = self.sharedProvider?.configuration {
			print("CallkitIncoming: CXProviderConfiguration.supportsVideo set to: \(config.supportsVideo)")
		}
		
		
		let uuid = UUID(uuidString: data.uuid)
		
		configurAudioSession()
		self.sharedProvider?.reportNewIncomingCall(with: uuid!, update: callUpdate) { error in
			if(error == nil) {
				self.configurAudioSession()
				let call = Call(uuid: uuid!, data: data)
				call.handle = data.handle
				self.callManager.addCall(call)
				self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_INCOMING, data.toJSON())
				self.endCallNotExist(data)
			} else {
				print("CallkitIncoming: Error reporting new incoming call: \(error?.localizedDescription ?? "unknown error")")
			}
		}
	}
	
	@objc public func startCall(_ data: Data, fromPushKit: Bool) {
		self.isFromPushKit = fromPushKit
		if(fromPushKit){
			self.data = data
		}
		initCallkitProvider(data)
		self.callManager.startCall(data)
	}
	
	@objc public func muteCall(_ callId: String, isMuted: Bool) {
		guard let callId = UUID(uuidString: callId),
			  let call = self.callManager.callWithUUID(uuid: callId) else {
			return
		}
		if call.isMuted == isMuted {
			self.sendMuteEvent(callId.uuidString, isMuted)
		} else {
			self.callManager.muteCall(call: call, isMuted: isMuted)
		}
	}
	
	@objc public func holdCall(_ callId: String, onHold: Bool) {
		guard let callId = UUID(uuidString: callId),
			  let call = self.callManager.callWithUUID(uuid: callId) else {
			return
		}
		if call.isOnHold == onHold {
			self.sendMuteEvent(callId.uuidString,  onHold)
		} else {
			self.callManager.holdCall(call: call, onHold: onHold)
		}
	}
	
	@objc public func endCall(_ data: Data) {
		var call: Call? = nil
		if(self.isFromPushKit){
			call = Call(uuid: UUID(uuidString: self.data!.uuid)!, data: data)
			self.isFromPushKit = false
			self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, data.toJSON())
		}else {
			call = Call(uuid: UUID(uuidString: data.uuid)!, data: data)
		}
		self.callManager.endCall(call: call!)
	}
	
	@objc public func connectedCall(_ data: Data) {
		var call: Call? = nil
		if(self.isFromPushKit){
			call = Call(uuid: UUID(uuidString: self.data!.uuid)!, data: data)
			self.isFromPushKit = false
		}else {
			call = Call(uuid: UUID(uuidString: data.uuid)!, data: data)
		}
		self.callManager.connectedCall(call: call!)
	}
	
	@objc public func activeCalls() -> [[String: Any]] {
		return self.callManager.activeCalls()
	}
	
	@objc public func endAllCalls() {
		self.isFromPushKit = false
		self.callManager.endCallAlls()
	}
	
	public func saveEndCall(_ uuid: String, _ reason: Int) {
		switch reason {
		case 1:
			self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.failed)
			break
		case 2, 6:
			self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.remoteEnded)
			break
		case 3:
			self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.unanswered)
			break
		case 4:
			self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.answeredElsewhere)
			break
		case 5:
			self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.declinedElsewhere)
			break
		default:
			break
		}
	}
	
	
	func endCallNotExist(_ data: Data) {
		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(data.duration)) {
			let call = self.callManager.callWithUUID(uuid: UUID(uuidString: data.uuid)!)
			if (call != nil && self.answerCall == nil && self.outgoingCall == nil) {
				self.callEndTimeout(data)
			}
		}
	}
	
	
	
	func callEndTimeout(_ data: Data) {
		self.saveEndCall(data.uuid, 3)
		guard let call = self.callManager.callWithUUID(uuid: UUID(uuidString: data.uuid)!) else {
			return
		}
		sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, data.toJSON())
		if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
			appDelegate.onTimeOut(call)
		}
	}
	
	func getHandleType(_ handleType: String?) -> CXHandle.HandleType {
		var typeDefault = CXHandle.HandleType.generic
		switch handleType {
		case "number":
			typeDefault = CXHandle.HandleType.phoneNumber
			break
		case "email":
			typeDefault = CXHandle.HandleType.emailAddress
		default:
			typeDefault = CXHandle.HandleType.generic
		}
		return typeDefault
	}
	
	func initCallkitProvider(_ data: Data) {
		if(self.sharedProvider == nil){
			self.sharedProvider = CXProvider(configuration: createConfiguration(data))
			self.sharedProvider?.setDelegate(self, queue: nil)
		}
		self.callManager.setSharedProvider(self.sharedProvider!)
	}
	
	func createConfiguration(_ data: Data) -> CXProviderConfiguration {
		let configuration = CXProviderConfiguration(localizedName: data.appName)
		configuration.supportsVideo = data.supportsVideo
		configuration.maximumCallGroups = data.maximumCallGroups
		configuration.maximumCallsPerCallGroup = data.maximumCallsPerCallGroup
		
		configuration.supportedHandleTypes = [
			CXHandle.HandleType.generic,
			CXHandle.HandleType.emailAddress,
			CXHandle.HandleType.phoneNumber
		]
		if #available(iOS 11.0, *) {
			configuration.includesCallsInRecents = data.includesCallsInRecents
		}
		if !data.iconName.isEmpty {
			if let image = UIImage(named: data.iconName) {
				configuration.iconTemplateImageData = image.pngData()
			} else {
				print("Unable to load icon \(data.iconName).");
			}
		}
		if !data.ringtonePath.isEmpty || data.ringtonePath != "system_ringtone_default"  {
			configuration.ringtoneSound = data.ringtonePath
		}
		return configuration
	}
	
	func sendDefaultAudioInterruptionNofificationToStartAudioResource(){
		var userInfo : [AnyHashable : Any] = [:]
		let intrepEndeRaw = AVAudioSession.InterruptionType.ended.rawValue
		userInfo[AVAudioSessionInterruptionTypeKey] = intrepEndeRaw
		userInfo[AVAudioSessionInterruptionOptionKey] = AVAudioSession.InterruptionOptions.shouldResume.rawValue
		NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: self, userInfo: userInfo)
	}
	
	func configurAudioSession(){
		if data?.configureAudioSession != false {
			let session = AVAudioSession.sharedInstance()
			do{
				try session.setCategory(AVAudioSession.Category.playAndRecord, options: [
					.allowBluetoothA2DP,
					.duckOthers,
					.allowBluetooth,
				])
				
				try session.setMode(self.getAudioSessionMode(data?.audioSessionMode))
				try session.setActive(data?.audioSessionActive ?? true)
				try session.setPreferredSampleRate(data?.audioSessionPreferredSampleRate ?? 44100.0)
				try session.setPreferredIOBufferDuration(data?.audioSessionPreferredIOBufferDuration ?? 0.005)
			}catch{
				print(error)
			}
		}
	}
	
	func getAudioSessionMode(_ audioSessionMode: String?) -> AVAudioSession.Mode {
		var mode = AVAudioSession.Mode.default
		switch audioSessionMode {
		case "gameChat":
			mode = AVAudioSession.Mode.gameChat
			break
		case "measurement":
			mode = AVAudioSession.Mode.measurement
			break
		case "moviePlayback":
			mode = AVAudioSession.Mode.moviePlayback
			break
		case "spokenAudio":
			mode = AVAudioSession.Mode.spokenAudio
			break
		case "videoChat":
			mode = AVAudioSession.Mode.videoChat
			break
		case "videoRecording":
			mode = AVAudioSession.Mode.videoRecording
			break
		case "voiceChat":
			mode = AVAudioSession.Mode.voiceChat
			break
		case "voicePrompt":
			if #available(iOS 12.0, *) {
				mode = AVAudioSession.Mode.voicePrompt
			} else {
					// Fallback on earlier versions
			}
			break
		default:
			mode = AVAudioSession.Mode.default
		}
		return mode
	}
	
	public func providerDidReset(_ provider: CXProvider) {
		for call in self.callManager.calls {
			call.endCall()
		}
		self.callManager.removeAllCalls()
	}
	
	public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
		let call = Call(uuid: action.callUUID, data: self.data!, isOutGoing: true)
		call.handle = action.handle.value
		configurAudioSession()
		call.hasStartedConnectDidChange = { [weak self] in
			self?.sharedProvider?.reportOutgoingCall(with: call.uuid, startedConnectingAt: call.connectData)
		}
		call.hasConnectDidChange = { [weak self] in
			self?.sharedProvider?.reportOutgoingCall(with: call.uuid, connectedAt: call.connectedData)
		}
		self.outgoingCall = call;
		self.callManager.addCall(call)
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_START, self.data?.toJSON())
		action.fulfill()
	}
	
	public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
		guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else{
			action.fail()
			return
		}
			// Removed redundant configurAudioSession and DispatchQueue.main.asyncAfter
			// The audio session activation for WebRTC should primarily be handled
			// in AppDelegate's didActivateAudioSession delegate method.
		
		call.hasConnectDidChange = { [weak self] in
			self?.sharedProvider?.reportOutgoingCall(with: call.uuid, connectedAt: call.connectedData)
		}
		self.answerCall = call
		sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ACCEPT, self.data?.toJSON())
		if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
			appDelegate.onAccept(call, action)
		}else {
			action.fulfill()
		}
	}
	
	public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
		guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
			if(self.answerCall == nil && self.outgoingCall == nil){
				sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, self.data?.toJSON())
			} else {
				sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, self.data?.toJSON())
			}
			action.fail()
			return
		}
		call.endCall()
		self.callManager.removeCall(call)
		if (self.answerCall == nil && self.outgoingCall == nil) {
			sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_DECLINE, self.data?.toJSON())
			if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
				appDelegate.onDecline(call, action)
			} else {
				action.fulfill()
			}
		}else {
			self.answerCall = nil
			sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, call.data.toJSON())
			if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
				appDelegate.onEnd(call, action)
			} else {
				action.fulfill()
			}
		}
	}
	
	
	public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
		guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
			action.fail()
			return
		}
		call.isOnHold = action.isOnHold
		call.isMuted = action.isOnHold
		self.callManager.setHold(call: call, onHold: action.isOnHold)
		sendHoldEvent(action.callUUID.uuidString, action.isOnHold)
		action.fulfill()
	}
	
	public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
		guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
			action.fail()
			return
		}
		call.isMuted = action.isMuted
		sendMuteEvent(action.callUUID.uuidString, action.isMuted)
		action.fulfill()
	}
	
	public func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
		guard (self.callManager.callWithUUID(uuid: action.callUUID)) != nil else {
			action.fail()
			return
		}
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_GROUP, [ "id": action.callUUID.uuidString, "callUUIDToGroupWith" : action.callUUIDToGroupWith?.uuidString])
		action.fulfill()
	}
	
	public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
		guard (self.callManager.callWithUUID(uuid: action.callUUID)) != nil else {
			action.fail()
			return
		}
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_DMTF, [ "id": action.callUUID.uuidString, "digits": action.digits, "type": action.type.rawValue ])
		action.fulfill()
	}
	
	public func provider(_ provider: CXProvider, performSetVideoEnabled action: CXSetVideoEnabledAction, completionHandler: @escaping () -> Void) {
			// ADD THIS PRINT STATEMENT:
		print("CallkitIncoming: provider(_:performSetVideoEnabled:) called. isVideoEnabled: \(action.isVideoEnabled)")
		
		let callUUID = action.call.uuid.uuidString
		let isVideoEnabled = action.isVideoEnabled
		
		let body: [String: Any?] = [
			"id": callUUID,
			"isVideoEnabled": isVideoEnabled
		]
		
			// Use the existing sendEvent method to push this to Flutter
		self.sendEvent("actionToggleVideo", body)
		
			// You must call fulfill() and the completion handler for CallKit to process the action
		action.fulfill()
		completionHandler()
	}
	
	
	public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) { 
		guard let call = self.callManager.callWithUUID(uuid: action.uuid) else {
			action.fail()
			return
		}
		sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, self.data?.toJSON())
		if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
			appDelegate.onTimeOut(call)
		}
		action.fulfill()
	}
	
	public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
		
		if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
			appDelegate.didActivateAudioSession(audioSession)
		}
		
		if(self.answerCall?.hasConnected ?? false){
			sendDefaultAudioInterruptionNofificationToStartAudioResource()
			return
		}
		if(self.outgoingCall?.hasConnected ?? false){
			sendDefaultAudioInterruptionNofificationToStartAudioResource()
			return
		}
		self.outgoingCall?.startCall(withAudioSession: audioSession) {success in
			if success {
				self.callManager.addCall(self.outgoingCall!)
				self.outgoingCall?.startAudio()
			}
		}
		self.answerCall?.ansCall(withAudioSession: audioSession) { success in
			if success{
				self.answerCall?.startAudio()
			}
		}
		sendDefaultAudioInterruptionNofificationToStartAudioResource()
		configurAudioSession()
		
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_AUDIO_SESSION, [ "isActivate": true ])
	}
	
	public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
		
		if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
			appDelegate.didDeactivateAudioSession(audioSession)
		}
		
		if self.outgoingCall?.isOnHold ?? false || self.answerCall?.isOnHold ?? false{
			print("Call is on hold")
			return
		}
		
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_AUDIO_SESSION, [ "isActivate": false ])
	}
	
	private func sendMuteEvent(_ id: String, _ isMuted: Bool) {
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_MUTE, [ "id": id, "isMuted": isMuted ])
	}
	
	private func sendHoldEvent(_ id: String, _ isOnHold: Bool) {
		self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_HOLD, [ "id": id, "isOnHold": isOnHold ])
	}
	
}

class EventCallbackHandler: NSObject, FlutterStreamHandler {
	private var eventSink: FlutterEventSink?
	
	public func send(_ event: String, _ body: Any) {
		let data: [String : Any] = [
			"event": event,
			"body": body
		]
		eventSink?(data)
	}
	
	func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
		self.eventSink = events
		return nil
	}
	
	func onCancel(withArguments arguments: Any?) -> FlutterError? {
		self.eventSink = nil
		return nil
	}
}
