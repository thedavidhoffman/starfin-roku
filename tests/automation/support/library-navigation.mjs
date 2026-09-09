import { waitFor } from './lifecycle.mjs';

async function findConfiguredLibrary(environment, libraryName, collectionType) {
  return waitFor(async () => {
    const countResponse = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#shelvesGroup.getChildCount()'
    });
    const shelfCount = countResponse.found ? countResponse.value : 0;

    for (let shelfIndex = 0; shelfIndex < shelfCount; shelfIndex += 1) {
      const shelf = await environment.odc.getValues({
        requests: {
          title: { base: 'scene', keyPath: `#shelvesGroup.${shelfIndex}.rowContent.title` },
          itemCount: { base: 'scene', keyPath: `#shelvesGroup.${shelfIndex}.rowContent.getChildCount()` }
        }
      });
      if (shelf.results.title?.value !== 'My Media') continue;

      const itemCount = shelf.results.itemCount?.value ?? 0;
      for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
        const response = await environment.odc.getValue({
          base: 'scene',
          keyPath: `#shelvesGroup.${shelfIndex}.rowContent.${itemIndex}.raw`
        });
        const item = response.value;
        if (
          item?.Name === libraryName
          && String(item.CollectionType ?? '').toLowerCase() === collectionType.toLowerCase()
        ) {
          return { item, shelfIndex };
        }
      }
    }

    return false;
  }, `the ${libraryName} library in My Media`, 45000);
}

async function openConfiguredLibrary(environment, options) {
  const { item, shelfIndex } = await findConfiguredLibrary(
    environment,
    options.libraryName,
    options.collectionType
  );

  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#shelvesGroup.${shelfIndex}.selectedItem`,
    value: { item, rowKey: 'libraries' }
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.0.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' },
        responseOk: { base: 'scene', keyPath: `#${options.taskId}.response.ok` },
        taskState: { base: 'scene', keyPath: `#${options.taskId}.state` }
      }
    });
    return values.results.childCount?.value === 1
      && values.results.pageType?.value === options.pageType
      && values.results.pageVisible?.value === true
      && values.results.responseOk?.value === true
      && ['done', 'stop'].includes(String(values.results.taskState?.value ?? '').toLowerCase());
  }, `the ${options.libraryName} library to load`, 120000);
}

export { findConfiguredLibrary, openConfiguredLibrary };
