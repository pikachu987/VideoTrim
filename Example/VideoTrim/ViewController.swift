//
//  ViewController.swift
//  VideoTrim
//
//  Created by pikachu987 on 09/12/2020.
//  Copyright (c) 2020 pikachu987. All rights reserved.
//

import UIKit
import VideoTrim
import AVKit
import Photos

class ViewController: UIViewController {

    private let playerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let playerLayer: AVPlayerLayer = {
        return AVPlayerLayer()
    }()

    private let videoTrim: VideoTrim = {
        let videoTrim = VideoTrim()
        videoTrim.translatesAutoresizingMaskIntoConstraints = false
        videoTrim.topMargin = 4
        videoTrim.bottomMargin = 8
        return videoTrim
    }()

    private var timer: Timer?

    private var startTime: CMTime = .zero
    private var endTime: CMTime = .zero
    private var durationTime: CMTime = .zero

    private var player: AVPlayer? {
        return self.playerLayer.player
    }

    private var isPlaying: Bool {
        guard let player = self.player else { return false }
        return player.rate != 0 && player.error == nil
    }

    private var url: URL? {
        didSet {
            if let url = self.url {
                self.playerLayer.player = AVPlayer(url: url)
                self.playerLayer.frame = self.playerContainerView.bounds
            }
        }
    }

    private var asset: AVAsset? {
        didSet {
            if let asset = self.asset {
                self.playerLayer.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                self.playerLayer.frame = self.playerContainerView.bounds
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.view.backgroundColor = .black

        self.view.addSubview(self.playerContainerView)
        self.view.addSubview(self.videoTrim)

        self.view.addConstraints([
            NSLayoutConstraint(item: self.playerContainerView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: self.playerContainerView, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: self.playerContainerView, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: 0)
        ])

        self.playerContainerView.addConstraints([
            NSLayoutConstraint(item: self.playerContainerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 240)
        ])

        self.view.addConstraints([
            NSLayoutConstraint(item: self.playerContainerView, attribute: .bottom, relatedBy: .equal, toItem: self.videoTrim, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: self.videoTrim, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: self.videoTrim, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: 0)
        ])

        self.playerContainerView.layoutIfNeeded()
        self.playerContainerView.layer.addSublayer(self.playerLayer)
        self.playerLayer.frame = self.playerContainerView.bounds

        self.videoTrim.delegate = self

        self.playerContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.togglePlay(_:))))

        let button = UIButton(type: .system)
        button.setTitle("Album", for: .normal)
        button.addTarget(self, action: #selector(self.videoTap(_:)), for: .touchUpInside)
        self.navigationItem.titleView = button

        self.permission { (alertController) in
            if alertController != nil {
                self.showPublicVideo()
                return
            }
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let assets = PHAsset.fetchAssets(with: fetchOptions)
            if let asset = assets.lastObject {
                let videoRequestOptions = PHVideoRequestOptions()
                videoRequestOptions.isNetworkAccessAllowed = true
                PHCachingImageManager.default().requestAVAsset(forVideo: asset, options: videoRequestOptions) { (asset, _, _) in
                    DispatchQueue.main.async {
                        if let urlAsset = asset as? AVURLAsset {
                            self.url = urlAsset.url
                            self.videoTrim.asset = AVAsset(url: urlAsset.url)
                            self.updateTrimTime()
                        } else if let asset = asset {
                            self.asset = asset
                            self.videoTrim.asset = asset
                            self.updateTrimTime()
                        }
                    }
                }
            } else {
                self.showPublicVideo()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc private func videoTap(_ sender: UIButton) {
        self.permission { (alertController) in
            if let alertController = alertController {
                self.present(alertController, animated: true, completion: nil)
                return
            }
        }
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.mediaTypes = ["public.movie"]
        pickerController.sourceType = .photoLibrary
        self.present(pickerController, animated: true, completion: nil)
    }

    @objc private func togglePlay(_ sender: UIButton) {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    @objc private func timerAction(_ sender: Timer) {
        self.videoTrim.currentTime = self.player?.currentTime()
        if let player = self.player {
            let current = player.currentTime()
            let currentTime = CGFloat(current.value) / CGFloat(current.timescale)
            let endTime = CGFloat(self.endTime.value) / CGFloat(self.endTime.timescale)
            if currentTime >= endTime {
                sender.invalidate()
                self.pause()
                self.player?.seek(to: self.startTime, completionHandler: { (_) in
                    self.videoTrim.currentTime = self.player?.currentTime()
                })
            }
        }
    }

    private func showPublicVideo() {
        guard let url = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4") else { return }
        print("Start Download")
        DispatchQueue.global().async {
            URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil).dataTask(with: url) { (data, response, error) in
                if let error = error {
                    print("error: \(error)")
                    return
                }
                guard let data = data else { return }
                let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                let targetURL = tempDirectoryURL.appendingPathComponent("BigBuckBunny.mp4")
                do {
                    try data.write(to: targetURL)
                    DispatchQueue.main.async {
                        self.url = targetURL
                        self.videoTrim.asset = AVAsset(url: targetURL)
                        self.updateTrimTime()
                    }
                } catch {
                    
                }
            }.resume()
        }
    }

    private func play() {
        guard let player = self.playerLayer.player else { return }
        player.play()
        self.timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.timerAction(_:)), userInfo: nil, repeats: true)
        self.videoTrim.currentTime = self.player?.currentTime()
    }

    private func pause() {
        guard let player = self.playerLayer.player else { return }
        player.pause()
        self.timer?.invalidate()
        self.timer = nil
    }

    private func updateTrimTime() {
        self.startTime = self.videoTrim.startTime
        self.endTime = self.videoTrim.endTime
        self.durationTime = self.videoTrim.durationTime
    }

    private func permission(_ handler: @escaping ((UIAlertController?) -> Void)) {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            DispatchQueue.main.async { handler(nil) }
        } else if PHPhotoLibrary.authorizationStatus() == .denied {
            let alertController = UIAlertController(title: "Permission", message: "Permission", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
            handler(alertController)
        } else {
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .authorized:
                    DispatchQueue.main.async { handler(nil) }
                default:
                    let alertController = UIAlertController(title: "Permission", message: "Permission", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                    handler(alertController)
                }
            }
        }
    }
}

// MARK: ViewController + VideoTrimDelegate
extension ViewController: VideoTrimDelegate {
    func videoTrimStartTrimChange(_ videoTrim: VideoTrim) {
        self.pause()
    }

    func videoTrimEndTrimChange(_ videoTrim: VideoTrim) {
        self.updateTrimTime()
    }

    func videoTrimPlayTimeChange(_ videoTrim: VideoTrim) {
        self.player?.seek(to: CMTime(value: CMTimeValue(videoTrim.playTime.value + videoTrim.startTime.value), timescale: videoTrim.playTime.timescale))
        self.updateTrimTime()
    }
}

// MARK: ViewController + UIImagePickerControllerDelegate, UINavigationControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let url = info[.mediaURL] as? URL else { return }
        self.url = url
        let asset = AVAsset(url: url)
        self.videoTrim.asset = asset
        self.updateTrimTime()
    }
}
