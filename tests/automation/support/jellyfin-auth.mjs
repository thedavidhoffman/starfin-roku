export function authorizationHeader(token) {
  return `MediaBrowser Client="Starfin Automation", Device="Test", DeviceId="starfin-automation", Version="1", Token="${token}"`;
}
