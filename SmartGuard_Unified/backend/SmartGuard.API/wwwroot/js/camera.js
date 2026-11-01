/**
 * SmartGuard Unified - Capybara Live Surveillance Camera Controller
 * Manages video feed, snapshot capture, recording, night vision, and HUD overlay.
 */

const CameraController = (function() {
  let videoEl = null;
  let canvasEl = null;
  let simulatedImgEl = null;
  let mediaStream = null;
  let mediaRecorder = null;
  let recordedChunks = [];
  let isRecording = false;
  let recordingTimer = null;
  let recordingSeconds = 0;
  let isNightVision = false;
  let isAudioMuted = true;
  let currentQuality = '1080p';
  let isStreaming = false;

  // Real evidence images fallback for CCTV simulation
  let evidenceList = [];
  let currentEvidenceIndex = 0;
  let simulationInterval = null;

  function init(videoElementId, canvasElementId, simulatedImgId) {
    videoEl = document.getElementById(videoElementId);
    canvasEl = document.getElementById(canvasElementId);
    simulatedImgEl = document.getElementById(simulatedImgId);

    // Setup live clock on HUD
    startLiveClock();
  }

  function setEvidenceImages(images) {
    if (images && images.length > 0) {
      evidenceList = images.map(img => img.relativeUrl || img);
    }
  }

  // Start Live Surveillance
  async function startStream() {
    isStreaming = true;
    updateStatusUI(true);

    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        const constraints = {
          video: {
            width: currentQuality === '1080p' ? 1920 : (currentQuality === '720p' ? 1280 : 640),
            height: currentQuality === '1080p' ? 1080 : (currentQuality === '720p' ? 720 : 480),
            facingMode: 'user'
          },
          audio: !isAudioMuted
        };

        try {
          mediaStream = await navigator.mediaDevices.getUserMedia(constraints);
          if (videoEl) {
            videoEl.srcObject = mediaStream;
            videoEl.style.display = 'block';
            if (simulatedImgEl) simulatedImgEl.style.display = 'none';
            await videoEl.play();
            return { success: true, mode: 'webcam' };
          }
        } catch (camErr) {
          console.log('[Camera] Browser webcam not accessible, activating CCTV Surveillance Simulation:', camErr.message);
          startSimulationStream();
          return { success: true, mode: 'simulation' };
        }
      } else {
        startSimulationStream();
        return { success: true, mode: 'simulation' };
      }
    } catch (err) {
      console.warn('[Camera] Failed to start stream:', err);
      startSimulationStream();
      return { success: true, mode: 'simulation' };
    }
  }

  // Stop Live Surveillance
  function stopStream() {
    isStreaming = false;
    updateStatusUI(false);

    if (mediaStream) {
      mediaStream.getTracks().forEach(track => track.stop());
      mediaStream = null;
    }
    if (videoEl) {
      videoEl.srcObject = null;
    }
    if (simulationInterval) {
      clearInterval(simulationInterval);
      simulationInterval = null;
    }
  }

  // CCTV Evidence-driven simulation stream
  function startSimulationStream() {
    if (videoEl) videoEl.style.display = 'none';
    if (simulatedImgEl) {
      simulatedImgEl.style.display = 'block';
      
      const updateFrame = () => {
        if (evidenceList.length > 0) {
          simulatedImgEl.src = evidenceList[currentEvidenceIndex % evidenceList.length];
          currentEvidenceIndex++;
        } else {
          // Fallback to default Capybara mascot surveillance poster
          simulatedImgEl.src = '/images/3bc65821-0388-43aa-aba6-16fc6a3912a4.png';
        }
      };

      updateFrame();
      if (!simulationInterval) {
        simulationInterval = setInterval(updateFrame, 4000);
      }
    }
  }

  // Snapshot Capture & Upload to Backend
  async function takeSnapshot(deviceId) {
    if (!canvasEl) return null;
    const ctx = canvasEl.getContext('2d');
    canvasEl.width = 1280;
    canvasEl.height = 720;

    if (mediaStream && videoEl && videoEl.videoWidth) {
      ctx.drawImage(videoEl, 0, 0, canvasEl.width, canvasEl.height);
    } else if (simulatedImgEl && simulatedImgEl.complete) {
      ctx.drawImage(simulatedImgEl, 0, 0, canvasEl.width, canvasEl.height);
    } else {
      // Draw simulated frame
      ctx.fillStyle = '#1C293B';
      ctx.fillRect(0, 0, canvasEl.width, canvasEl.height);
      ctx.fillStyle = '#405C83';
      ctx.font = 'bold 36px Inter, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('SMARTGUARD CAPYBARA SURVEILLANCE', canvasEl.width / 2, canvasEl.height / 2);
    }

    // Add Surveillance Timestamp & Watermark on Image
    const now = new Date();
    const timeStr = now.toISOString().replace('T', ' ').substring(0, 19);
    ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
    ctx.fillRect(20, canvasEl.height - 60, 420, 40);
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 20px monospace';
    ctx.textAlign = 'left';
    ctx.fillText(`CAM-01 [FHD] ${timeStr}`, 30, canvasEl.height - 34);

    return new Promise(resolve => {
      canvasEl.toBlob(async blob => {
        if (!blob) {
          resolve(null);
          return;
        }

        const file = new File([blob], `snap_${Date.now()}.jpg`, { type: 'image/jpeg' });
        const formData = new FormData();
        formData.append('File', file);
        if (deviceId) {
          formData.append('DeviceId', deviceId);
        }

        try {
          if (window.SmartGuardApi && window.SmartGuardApi.isAuthenticated()) {
            const result = await window.SmartGuardApi.uploadEvidence(formData);
            resolve({ blob, result, previewUrl: URL.createObjectURL(blob) });
          } else {
            resolve({ blob, previewUrl: URL.createObjectURL(blob) });
          }
        } catch (err) {
          console.warn('[Camera] Upload error, keeping local blob:', err);
          resolve({ blob, previewUrl: URL.createObjectURL(blob) });
        }
      }, 'image/jpeg', 0.92);
    });
  }

  // Recording Controls
  function toggleRecording(onTickCallback, onFinishCallback) {
    if (isRecording) {
      stopRecording(onFinishCallback);
      return false;
    } else {
      startRecording(onTickCallback);
      return true;
    }
  }

  function startRecording(onTickCallback) {
    if (!isStreaming) startStream();
    isRecording = true;
    recordedChunks = [];
    recordingSeconds = 0;

    const stream = (videoEl && videoEl.srcObject) ? videoEl.srcObject : canvasEl?.captureStream(25);
    if (stream) {
      try {
        mediaRecorder = new MediaRecorder(stream, { mimeType: 'video/webm;codecs=vp9,opus' });
      } catch {
        try {
          mediaRecorder = new MediaRecorder(stream);
        } catch {
          mediaRecorder = null;
        }
      }

      if (mediaRecorder) {
        mediaRecorder.ondataavailable = e => {
          if (e.data && e.data.size > 0) recordedChunks.push(e.data);
        };
        mediaRecorder.start(1000);
      }
    }

    recordingTimer = setInterval(() => {
      recordingSeconds++;
      if (onTickCallback) onTickCallback(formatTime(recordingSeconds));
    }, 1000);
  }

  function stopRecording(onFinishCallback) {
    isRecording = false;
    if (recordingTimer) {
      clearInterval(recordingTimer);
      recordingTimer = null;
    }

    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.onstop = () => {
        const blob = new Blob(recordedChunks, { type: 'video/webm' });
        const videoUrl = URL.createObjectURL(blob);
        if (onFinishCallback) onFinishCallback({ blob, videoUrl, duration: recordingSeconds });
      };
      mediaRecorder.stop();
    } else {
      if (onFinishCallback) onFinishCallback({ duration: recordingSeconds });
    }
  }

  // Night Vision Filter
  function toggleNightVision() {
    isNightVision = !isNightVision;
    const box = document.querySelector('.viewer-screen-box');
    if (box) {
      box.classList.toggle('night-vision', isNightVision);
    }
    return isNightVision;
  }

  // Audio Toggle
  function toggleAudio() {
    isAudioMuted = !isAudioMuted;
    if (mediaStream) {
      mediaStream.getAudioTracks().forEach(track => {
        track.enabled = !isAudioMuted;
      });
    }
    return isAudioMuted;
  }

  // Fullscreen Toggle
  function toggleFullscreen(viewerElement) {
    if (!document.fullscreenElement) {
      if (viewerElement.requestFullscreen) viewerElement.requestFullscreen();
      else if (viewerElement.webkitRequestFullscreen) viewerElement.webkitRequestFullscreen();
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
    }
  }

  // Quality Setting
  function setQuality(quality) {
    currentQuality = quality;
    if (isStreaming && mediaStream) {
      startStream(); // Re-apply constraints
    }
  }

  // Live HUD Clock
  function startLiveClock() {
    const clockEl = document.getElementById('hudLiveClock');
    if (!clockEl) return;

    const update = () => {
      const now = new Date();
      clockEl.textContent = now.toLocaleTimeString('en-US', { hour12: false }) + ' UTC+' + (-(now.getTimezoneOffset() / 60));
    };

    update();
    setInterval(update, 1000);
  }

  function updateStatusUI(streaming) {
    const hudRec = document.getElementById('hudRecBadge');
    if (hudRec) {
      hudRec.style.display = streaming ? 'flex' : 'none';
    }
  }

  function formatTime(sec) {
    const m = Math.floor(sec / 60).toString().padStart(2, '0');
    const s = (sec % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  }

  return {
    init,
    startStream,
    stopStream,
    setEvidenceImages,
    takeSnapshot,
    toggleRecording,
    toggleNightVision,
    toggleAudio,
    toggleFullscreen,
    setQuality,
    isStreaming: () => isStreaming,
    isRecording: () => isRecording
  };
})();

window.CameraController = CameraController;

