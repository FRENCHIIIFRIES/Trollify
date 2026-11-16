//! Spotify Connect player for Trollify, built on librespot.
//! The iPad shows up as a Connect device. First run: pick it from Spotify on another device
//! (zeroconf hands over your login); the login is then cached on disk.

use std::ffi::CStr;
use std::os::raw::c_char;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;

static STATUS: Mutex<String> = Mutex::new(String::new());
static STARTED: AtomicBool = AtomicBool::new(false);

fn set(s: impl Into<String>) {
    if let Ok(mut g) = STATUS.lock() {
        *g = s.into();
    }
}

/// Copies the latest status line into `buf` (NUL-terminated). Returns the length written.
#[no_mangle]
pub extern "C" fn trollify_status(buf: *mut c_char, len: usize) -> usize {
    if buf.is_null() || len == 0 {
        return 0;
    }
    let s = STATUS.lock().map(|g| g.clone()).unwrap_or_default();
    let n = s.len().min(len - 1);
    unsafe {
        std::ptr::copy_nonoverlapping(s.as_ptr(), buf as *mut u8, n);
        *buf.add(n) = 0;
    }
    n
}

/// Starts the player on a background thread. Returns 0 on start, 1 if already running.
#[no_mangle]
pub extern "C" fn trollify_start(name: *const c_char, cache_dir: *const c_char) -> i32 {
    if name.is_null() || cache_dir.is_null() || STARTED.swap(true, Ordering::SeqCst) {
        return 1;
    }
    let name = unsafe { CStr::from_ptr(name) }.to_string_lossy().into_owned();
    let cache = unsafe { CStr::from_ptr(cache_dir) }.to_string_lossy().into_owned();
    set("STARTING");
    let spawned = std::thread::Builder::new().stack_size(8 << 20).spawn(move || {
        let outcome = std::panic::catch_unwind(|| {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .worker_threads(2)
                .enable_all()
                .build()
                .expect("tokio runtime");
            rt.block_on(run(name, cache))
        });
        match outcome {
            Ok(Ok(())) => set("STOPPED"),
            Ok(Err(e)) => set(format!("ERROR {e}")),
            Err(_) => set("ERROR PLAYER CRASHED"),
        }
        STARTED.store(false, Ordering::SeqCst);
    });
    if spawned.is_ok() {
        0
    } else {
        STARTED.store(false, Ordering::SeqCst);
        -1
    }
}

async fn run(name: String, cache_dir: String) -> Result<(), Box<dyn std::error::Error>> {
    use futures_util::StreamExt;
    use librespot::connect::{ConnectConfig, Spirc};
    use librespot::core::cache::Cache;
    use librespot::core::config::{DeviceType, SessionConfig};
    use librespot::core::session::Session;
    use librespot::discovery::Discovery;
    use librespot::playback::audio_backend;
    use librespot::playback::config::{AudioFormat, PlayerConfig};
    use librespot::playback::mixer::{self, MixerConfig};
    use librespot::playback::player::Player;
    use sha1::{Digest, Sha1};

    let session_config = SessionConfig::default();
    let cache = Cache::new(Some(cache_dir.as_str()), Some(cache_dir.as_str()), None, None)?;

    let credentials = match cache.credentials() {
        Some(c) => c,
        None => {
            set("WAITING - OPEN SPOTIFY ON YOUR PC AND PICK THIS DEVICE");
            let device_id = hex::encode(Sha1::digest(name.as_bytes()));
            let mut discovery = Discovery::builder(device_id, session_config.client_id.clone())
                .name(name.clone())
                .device_type(DeviceType::Tablet)
                .launch()?;
            discovery.next().await.ok_or("DISCOVERY ENDED")?
        }
    };

    set("CONNECTING");
    let session = Session::new(session_config, Some(cache));
    let sink_builder = audio_backend::find(None).ok_or("NO AUDIO BACKEND")?;
    let mixer_builder = mixer::find(None).ok_or("NO MIXER")?;
    let mixer = mixer_builder(MixerConfig::default())?;
    let audio_format = AudioFormat::default();
    let player = Player::new(
        PlayerConfig::default(),
        session.clone(),
        mixer.get_soft_volume(),
        move || sink_builder(None, audio_format),
    );
    let connect_config = ConnectConfig {
        name: name.clone(),
        device_type: DeviceType::Tablet,
        ..Default::default()
    };
    let (_spirc, spirc_task) = Spirc::new(connect_config, session.clone(), credentials, player, mixer).await?;
    set("READY");
    spirc_task.await;
    Ok(())
}
