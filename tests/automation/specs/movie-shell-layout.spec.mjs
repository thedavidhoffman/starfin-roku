import assert from 'node:assert/strict';
import { categories, openSettings, openSettingsFromSystemMenu, selectRadioOption, closeAndSaveSettings } from '../support/settings.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { returnToHome } from '../support/tv-series.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { captureEvidence } from '../support/evidence.mjs';

describe('Starfin movie shell layout', function () {
  afterEach(async function () {
    const environment = await getAutomationEnvironment();
    const page = await environment.odc.getValue({ base: 'scene', keyPath: '#dynamicPageHost.1.subtype()' });
    if (page.value === 'Movie') await environment.odc.focusNode({ base: 'scene', keyPath: '#dynamicPageHost.1' });
    await returnToHome();
  });

  it('renders the saved Poster layout and navigates to cast without hiding details', async function () {
    const environment = await openMovieWithPoster();
    await assertPoster(environment);
    await environment.odc.callFunc({ base: 'scene', keyPath: '#dynamicPageHost.1', funcName: 'activate' });
    await environment.ecp.sendKeypress(environment.ecp.Key.Down, { wait: 400 });
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#cast' }), true);
    assert.equal(await read(environment, '#mediaShell.detailsVisible'), true);
    assert.equal(await read(environment, '#mediaToolbar.visible'), true);
    await captureEvidence(this, 'movie-poster-cast');
    await environment.ecp.sendKeypress(environment.ecp.Key.Up, { wait: 400 });
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#mediaToolbar' }), true);
    await captureEvidence(this, 'movie-poster-toolbar');
  });

  it('restores backdrop layout and returns to Poster after committed settings changes', async function () {
    const environment = await openMovieWithPoster();
    const people = await read(environment, '#castRows.content.0.getChildCount()');
    await openSettingsFromSystemMenu(environment, categories.mediaShell);
    await selectRadioOption(environment, 'movieShellLayoutOptions', 0);
    await closeAndSaveSettings(environment);
    await waitFor(async () => await read(environment, '#mediaShell.backgroundDisplay') === 'full-screen', 'the movie full backdrop');
    assert.equal(await read(environment, '#moviePosterGroup.visible'), false);
    assert.equal(await read(environment, '#mediaBackgroundFull.visible'), true);
    assert.equal(await read(environment, '#cast.viewportWidth'), 1848);
    assert.deepEqual(await read(environment, '#mediaToolbar.translation'), [0, 588]);
    await openSettingsFromSystemMenu(environment, categories.mediaShell);
    await selectRadioOption(environment, 'movieShellLayoutOptions', 3);
    await closeAndSaveSettings(environment);
    await assertPoster(environment);
    assert.equal(await read(environment, '#castRows.content.0.getChildCount()'), people);
    await captureEvidence(this, 'movie-poster-live');
  });
});

async function read(environment, keyPath) {
  return (await environment.odc.getValue({ base: 'scene', keyPath })).value;
}

async function openMovieWithPoster() {
  const { environment } = await openSettings(categories.mediaShell);
  await selectRadioOption(environment, 'movieShellLayoutOptions', 3);
  await closeAndSaveSettings(environment);
  await openConfiguredLibrary(environment, {
    libraryName: environment.movieLibrary, collectionType: 'movies',
    pageType: 'VideoLibrary', taskId: 'videoLibraryTask'
  });
  const count = await read(environment, '#itemsGrid.content.getChildCount()');
  let index = -1;
  for (let i = 0; i < count; i += 1) {
    if (await read(environment, `#itemsGrid.content.${i}.raw.ImageTags.Primary`)) { index = i; break; }
  }
  assert.ok(index >= 0, 'The configured movie library needs a movie poster.');
  await environment.odc.setValue({ base: 'scene', keyPath: '#itemsGrid.itemSelected', value: index });
  await waitFor(async () => await read(environment, '#dynamicPageHost.1.subtype()') === 'Movie'
    && await read(environment, '#mediaShell.mediaContent.mediaType') === 'movie'
    && await read(environment, '#cast.hasItems') === true, 'the movie details and cast', 120000);
  return environment;
}

async function assertPoster(environment) {
  await waitFor(async () => await read(environment, '#moviePosterGroup.visible') === true
    && await read(environment, '#moviePoster.loadStatus') === 'ready', 'the movie Poster artwork');
  assert.equal(await read(environment, '#mediaShell.backgroundDisplay'), 'poster');
  assert.deepEqual(await read(environment, '#mediaLayoutGroup.translation'), [-48, 0]);
  assert.deepEqual(await read(environment, '#moviePosterGroup.translation'), [96, 90]);
  const posterLeft = -48 + (await read(environment, '#moviePosterGroup.translation'))[0];
  const castRight = -48 + (await read(environment, '#contentGroup.translation'))[0]
    + (await read(environment, '#cast.translation'))[0] + await read(environment, '#cast.viewportWidth');
  assert.equal(posterLeft, 48);
  assert.equal(1920 - castRight, posterLeft);
  assert.ok((await read(environment, '#moviePosterGroup.maskUri')).endsWith('/movie-poster-mask.png'));
  assert.deepEqual(await read(environment, '#moviePosterGroup.maskSize'), [600, 900]);
  assert.equal(await read(environment, '#moviePoster.width'), 600);
  assert.equal(await read(environment, '#moviePoster.height'), 900);
  assert.equal(await read(environment, '#mediaBackgroundFull.visible'), false);
  assert.equal(await read(environment, '#mediaBackgroundPartialGroup.visible'), false);
  assert.equal(await read(environment, '#backgroundShade.visible'), false);
  assert.equal(await read(environment, '#contentGradient.visible'), false);
  assert.deepEqual(await read(environment, '#mediaShell.contentTranslation'), [768, 90]);
  assert.deepEqual(await read(environment, '#mediaToolbar.translation'), [672, 570]);
  assert.deepEqual(await read(environment, '#cast.translation'), [672, 681]);
  assert.equal(await read(environment, '#cast.viewportWidth'), 1152);
}
