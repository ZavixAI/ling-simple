import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import deviceInfo from '@ohos.deviceInfo';
import { pushService } from '@kit.PushKit';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import EventChannel, { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';

type LingValue = string | number | boolean | LingMap | LingMap[] | null;
type LingMap = Record<string, LingValue>;

class LingMethodHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;
  private plugin: LingBridgePlugin;

  constructor(context: common.UIAbilityContext, plugin: LingBridgePlugin) {
    this.context = context;
    this.plugin = plugin;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'isSimulator':
        result.success(false);
        break;
      case 'ready':
        result.success(this.plugin.consumePendingDeepLink());
        break;
      case 'getLatestContext':
      case 'requestForegroundLocationContext':
      case 'startTracking':
        result.success(this.plugin.latestDeviceContext());
        break;
      case 'getLocationPermissionState':
        result.success('unknown');
        break;
      case 'openSystemSettings':
        this.openSystemSettings();
        result.success(null);
        break;
      case 'configureBackend':
      case 'stopTracking':
      case 'cancelAllNotifications':
      case 'syncNotifications':
      case 'setApplicationBadgeCount':
      case 'setForegroundNotificationContext':
        result.success(null);
        break;
      case 'getPermissionState':
      case 'requestPermission':
        result.success('not_determined');
        break;
      case 'registerRemoteNotifications':
        this.plugin.remoteNotificationRegistration(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private openSystemSettings(): void {
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
    };
    this.context.startAbility(want).catch(() => {});
  }
}

class LingNotificationStreamHandler implements StreamHandler {
  private plugin: LingBridgePlugin;

  constructor(plugin: LingBridgePlugin) {
    this.plugin = plugin;
  }

  onListen(_args: object, events: EventSink): void {
    this.plugin.setNotificationEventSink(events);
  }

  onCancel(_args: object): void {
    this.plugin.setNotificationEventSink(null);
  }
}

export default class LingBridgePlugin implements FlutterPlugin {
  private context: common.UIAbilityContext;
  private channels: MethodChannel[] = [];
  private eventChannel: EventChannel | null = null;
  private notificationEventSink: EventSink | null = null;
  private pendingDeepLink: LingMap | null = null;
  private pushToken: string = '';

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  getUniqueClassName(): string {
    return 'LingBridgePlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    const messenger = binding.getBinaryMessenger();
    const handler = new LingMethodHandler(this.context, this);
    const methodChannelNames: string[] = [
      'ling/app_runtime',
      'ling/device_context',
      'ling/deep_link',
      'ling/calendar_notifications',
      'ling/review_request',
      'ling/apple_sign_in',
      'ling/apple_calendar',
      'ling/apple_speech_recognition',
      'ling/apple_membership_payment',
    ];
    methodChannelNames.forEach((name: string) => {
      const channel = new MethodChannel(messenger, name);
      channel.setMethodCallHandler(handler);
      this.channels.push(channel);
    });
    this.eventChannel = new EventChannel(
      messenger,
      'ling/calendar_notifications/events',
    );
    this.eventChannel.setStreamHandler(new LingNotificationStreamHandler(this));
    this.refreshPushToken();
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channels.forEach((channel: MethodChannel) => {
      channel.setMethodCallHandler(null);
    });
    this.channels = [];
    this.eventChannel?.setStreamHandler(null);
    this.eventChannel = null;
    this.notificationEventSink = null;
  }

  setNotificationEventSink(events: EventSink | null): void {
    this.notificationEventSink = events;
  }

  latestDeviceContext(): LingMap {
    return {
      device_model: deviceInfo.productModel,
      timezone: 'Asia/Shanghai',
    };
  }

  async remoteNotificationRegistration(result: MethodResult): Promise<void> {
    if (this.pushToken.length === 0) {
      await this.refreshPushToken();
    }
    if (this.pushToken.length === 0) {
      result.success(null);
      return;
    }
    result.success({
      push_token: this.pushToken,
      transport: 'harmony_push',
      provider: 'harmony',
      app_id: '',
    });
  }

  private async refreshPushToken(): Promise<void> {
    try {
      this.pushToken = await pushService.getToken();
    } catch (_error) {
      this.pushToken = '';
    }
  }

  consumePendingDeepLink(): LingMap | null {
    const payload = this.pendingDeepLink;
    this.pendingDeepLink = null;
    return payload;
  }

  handleWant(want: Want): boolean {
    const uri = want.uri ?? '';
    const payload = this.deepLinkPayload(uri);
    if (payload === null) {
      return false;
    }
    this.pendingDeepLink = payload;
    return true;
  }

  emitForegroundNotification(payload: LingMap): void {
    this.notificationEventSink?.success(payload);
  }

  private deepLinkPayload(uri: string): LingMap | null {
    return null;
  }

}
