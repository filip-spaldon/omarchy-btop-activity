import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'
import vm from 'node:vm'

const source = fs.readFileSync(new URL('../BarWidget.qml', import.meta.url), 'utf8')
const methods = ['moveCursor', 'activateCursor', 'launchBtop'].map(name => {
  const match = source.match(new RegExp(`    function ${name}\\([^)]*\\) \\{[\\s\\S]*?\\n    \\}`))
  assert.ok(match, `missing ${name}`)
  return match[0]
}).join('\n')
const textHandler = source.match(/onTextKey: function \(text\) \{[\s\S]*?\n            \}/)
assert.ok(textHandler, 'missing menu text-key handler')

function menu(page, selection) {
  const calls = []
  const context = vm.createContext({
    page, opened: true, mainIndex: selection, settingsIndex: selection, creationIndex: 0,
    settingsCount: 9, backIndex: 8, moreSettingsIndex: 7,
    keybindingsIndex: 1, customPathIndex: -1, updateIndex: 3,
    showSettings() { context.page = 'settings' },
    showMain() { context.page = 'main' },
    close() { context.opened = false },
    launchWhenConfigReady(action) { calls.push(['launch', action]) },
    cycleSetting(index, direction) { calls.push([index, direction]) },
  })
  context.root = context
  vm.runInContext(methods + '\n' + textHandler[0].replace(
    'onTextKey: function (text)', 'function textKey(text)'), context)
  return { context, calls }
}

test('b opens or focuses btop without closing or changing the current menu page', () => {
  for (const page of ['main', 'settings']) {
    for (const key of ['b', 'B']) {
      const { context, calls } = menu(page, 0)
      context.textKey(key)
      assert.equal(context.opened, true)
      assert.equal(context.page, page)
      assert.deepEqual(calls, [['launch', 'btop']])
    }
  }
})

test('Start btop also keeps the menu open when activated with Enter or clicked', () => {
  for (const activate of [ctx => ctx.activateCursor(), ctx => ctx.launchBtop()]) {
    const { context, calls } = menu('main', 0)
    activate(context)
    assert.equal(context.opened, true)
    assert.deepEqual(calls, [['launch', 'btop']])
  }
})

test('right enters Settings, just like Enter', () => {
  for (const activate of [ctx => ctx.moveCursor(1, 0), ctx => ctx.activateCursor()]) {
    const { context } = menu('main', 1)
    activate(context)
    assert.equal(context.page, 'settings')
  }
})

test('left on Back returns to the main menu, just like Enter', () => {
  for (const activate of [ctx => ctx.moveCursor(-1, 0), ctx => ctx.activateCursor()]) {
    const { context, calls } = menu('settings', 8)
    activate(context)
    assert.equal(context.page, 'main')
    assert.deepEqual(calls, [])
  }
})

test('horizontal movement does not launch other main-menu actions', () => {
  for (const selection of [0, 2]) {
    const { context } = menu('main', selection)
    context.moveCursor(1, 0)
    assert.equal(context.page, 'main')
  }
  const { context } = menu('main', 1)
  context.moveCursor(-1, 0)
  assert.equal(context.page, 'main')
})

test('left and right still adjust settings values', () => {
  const { context, calls } = menu('settings', 3)
  context.moveCursor(-1, 0)
  context.moveCursor(1, 0)
  assert.equal(context.page, 'settings')
  assert.deepEqual(calls, [[3, -1], [3, 1]])
})

test('right on Back does nothing; confirmation navigation stays unchanged', () => {
  const { context, calls } = menu('settings', 8)
  context.moveCursor(1, 0)
  assert.equal(context.page, 'settings')
  assert.deepEqual(calls, [])
  context.page = 'createSettings'
  context.moveCursor(1, 0)
  assert.equal(context.creationIndex, 1)
  context.moveCursor(-1, 0)
  assert.equal(context.creationIndex, 0)
})
