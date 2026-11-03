using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class DebugMenu : MonoBehaviour
{
	private Color selectedColor = new Color(1f, 1f, 1f, 1f);

	private Color notSelectedColor = new Color(1f, 1f, 1f, 0.6f);

	private Text[] menuOptions;

	private int currentIndex;

	private int previousIndex;

	private bool inputReceived;

	private int inputVal;

	private int inputOffsetVal;

	private int optionsCount;

	public bool paused;

	private static DebugMenu instance;

	private bool noClipOn;

	public static bool godModeOn;

	private bool maxDiff;

	public static DebugMenu Instance => instance;

	private void Awake()
	{
		if (instance != null && instance != this)
		{
			Object.Destroy(base.gameObject);
			return;
		}
		instance = this;
		Object.DontDestroyOnLoad(base.gameObject);
		menuOptions = GetComponentsInChildren<Text>();
		currentIndex = 0;
		previousIndex = 0;
		paused = false;
		optionsCount = menuOptions.Length;
		base.gameObject.SetActive(value: false);
	}

	public void Toggle()
	{
		Text[] array = menuOptions;
		for (int i = 0; i < array.Length; i++)
		{
			array[i].color = notSelectedColor;
		}
		SelectOption(currentIndex, playSound: false);
		if (!paused)
		{
			GameController.cameraController.blur.enabled = true;
			TimeScaleController.Pause(status: true);
			Player[] activePlayers = GameController.activePlayers;
			for (int i = 0; i < activePlayers.Length; i++)
			{
				activePlayers[i].enabled = false;
			}
			base.gameObject.SetActive(value: true);
			paused = true;
		}
		else
		{
			GameController.cameraController.blur.enabled = false;
			TimeScaleController.Pause(status: false);
			Player[] activePlayers = GameController.activePlayers;
			for (int i = 0; i < activePlayers.Length; i++)
			{
				activePlayers[i].enabled = true;
			}
			base.gameObject.SetActive(value: false);
			paused = false;
		}
	}

	private void Update()
	{
		if (paused)
		{
			HandleNavigation();
			if (InputController.GetAnyDeviceButtonDown("Confirm") != null)
			{
				ConfirmOption(currentIndex);
				Toggle();
			}
			if (InputController.GetAnyDeviceButtonDown("Cancel") != null)
			{
				Toggle();
			}
		}
	}

	private void HandleNavigation()
	{
		inputVal = (InputController.GetAnyDeviceDirection(InputDirection.Down) ? 1 : (InputController.GetAnyDeviceDirection(InputDirection.Up) ? (-1) : 0));
		if (inputVal == 0)
		{
			inputReceived = false;
		}
		else if (!inputReceived)
		{
			inputReceived = true;
			inputOffsetVal = inputVal * ((InputController.GetAnyDeviceButtonDown("Skill5") == null && !Input.GetKey(KeyCode.LeftShift)) ? 1 : 5);
			previousIndex = currentIndex;
			currentIndex += inputOffsetVal;
			if (currentIndex < 0)
			{
				currentIndex = optionsCount - 1;
			}
			else if (currentIndex >= optionsCount)
			{
				currentIndex = 0;
			}
			SelectOption(currentIndex);
		}
	}

	public void SelectOption(int index, bool playSound = true)
	{
		menuOptions[previousIndex].color = notSelectedColor;
		previousIndex = index;
		currentIndex = index;
		menuOptions[index].color = selectedColor;
		SoundManager.PlayAudio("MenuMove", 1f, ignoreTimeRestriction: true);
	}

	public void ConfirmOption(int index)
	{
		switch (menuOptions[index].gameObject.name)
		{
		case "ReloadScene":
			ReloadScene();
			break;
		case "SkipStage":
			SkipStage();
			break;
		case "GodMode":
			GodMode();
			break;
		case "MaxDiff":
			MaxDiff();
			break;
		case "NoClip":
			NoClip();
			break;
		case "Money":
			Money();
			break;
		case "HideUI":
			HideUI();
			break;
		case "ForceCoop":
			ForceCoop();
			break;
		case "SpawnSkillMerchant":
			SpawnSkillMerchant();
			break;
		case "SpawnAlly":
			SpawnAlly();
			break;
		case "WrathOfTheDeveloper":
			WrathOfTheDeveloper();
			break;
		case "UnlockEverything":
			UnlockEverything();
			break;
		case "PrintGameData":
			PrintGameData();
			break;
		case "ClearSettings":
			ClearSettings();
			break;
		case "ClearGameData":
			ClearGameData();
			break;
		case "ToggleCameraLock":
			ToggleCameraLock();
			break;
		case "DevHub":
			DevHub();
			break;
		case "GotoSpellStore":
			GotoSpellStore();
			break;
		case "GotoItemStore":
			GotoItemStore();
			break;
		case "SpawnWardrobe":
			SpawnWardrobe();
			break;
		}
	}

	public void WrathOfTheDeveloper()
	{
		AttackInfo attackInfo = new AttackInfo();
		attackInfo.skillID = "WrathOfDeveloper";
		attackInfo.damage = 9999;
		List<GameObject> list = new List<GameObject>();
		list.AddRange(GameController.allies);
		list.AddRange(GameController.enemies);
		foreach (GameObject item in list)
		{
			if (!(item == null))
			{
				Entity component = item.GetComponent<Entity>();
				if (!(component == null) && !(component.health == null))
				{
					component.health.TakeDamage(attackInfo);
				}
			}
		}
		list.Clear();
	}

	public void ReloadScene()
	{
		GameController.LoadLevel(Application.loadedLevelName);
	}

	public void SkipStage()
	{
		if (NextLevelLoader.InTierScene())
		{
			Player[] activePlayers = GameController.activePlayers;
			for (int i = 0; i < activePlayers.Length; i++)
			{
				activePlayers[i].transform.position = Level.exitPosition + Vector2.down * 3f;
			}
		}
	}

	public void GotoSpellStore()
	{
		GameObject gameObject = GameObject.Find("SkillMerchant");
		if (gameObject != null && NextLevelLoader.InTierScene())
		{
			Player[] activePlayers = GameController.activePlayers;
			for (int i = 0; i < activePlayers.Length; i++)
			{
				activePlayers[i].transform.position = gameObject.transform.position;
			}
		}
	}

	public void GotoItemStore()
	{
		GameObject gameObject = GameObject.Find("ItemMerchant");
		if (gameObject != null && NextLevelLoader.InTierScene())
		{
			Player[] activePlayers = GameController.activePlayers;
			for (int i = 0; i < activePlayers.Length; i++)
			{
				activePlayers[i].transform.position = gameObject.transform.position;
			}
		}
	}

	public void NoClip()
	{
		Player[] activePlayers = GameController.activePlayers;
		foreach (Player obj in activePlayers)
		{
			obj.floorContact.SetActive(noClipOn);
			obj.fall.enabled = noClipOn;
		}
		noClipOn = !noClipOn;
	}

	public void GodMode()
	{
		Player[] activePlayers;
		if (!godModeOn)
		{
			activePlayers = GameController.activePlayers;
			foreach (Player player in activePlayers)
			{
				GameUI.BroadcastNoticeMessage("<color=red>God Mode</color> Enabled!");
				player.health.invulnerable = true;
				player.health.healthStat.CurrentValue = player.health.healthStat.ModifiedValue;
				foreach (Player.SkillState value in player.skillsDict.Values)
				{
					value.cooldownRef.statData = null;
					value.cooldownRef.MaxTime = 0.1f;
					value.SetEmpowered(givenStatus: true, EmpowerStatMods.DebugEmpowerMod);
					value.isUltimate = true;
				}
			}
			godModeOn = true;
			return;
		}
		activePlayers = GameController.activePlayers;
		foreach (Player obj in activePlayers)
		{
			GameUI.BroadcastNoticeMessage("<color=red>God Mode</color> Disabled!");
			obj.health.invulnerable = false;
			foreach (Player.SkillState value2 in obj.skillsDict.Values)
			{
				value2.cooldownRef.statData = value2.skillData;
				value2.SetEmpowered(givenStatus: false, EmpowerStatMods.DebugEmpowerMod);
				value2.isUltimate = false;
			}
		}
		godModeOn = false;
	}

	public void MaxDiff()
	{
		maxDiff = !maxDiff;
		EnemyGlobalStatManager.useDiffScaling = maxDiff;
		GameUI.BroadcastNoticeMessage("Max Difficulty: " + maxDiff);
		GameController.startingDifficulty = (maxDiff ? 3 : 0);
	}

	public void Money()
	{
		GameUI.BroadcastNoticeMessage("Make it rain!");
		if (Player.goldWallet != null)
		{
			Player.goldWallet.Deposit(9999);
		}
		if (Player.platWallet != null)
		{
			Player.platWallet.Deposit(999);
		}
	}

	public void ForceCoop()
	{
		GameController.coopOn = !GameController.coopOn;
		Debug.Log("Coop status: " + GameController.coopOn);
		Player[] activePlayers = GameController.activePlayers;
		for (int i = 0; i < activePlayers.Length; i++)
		{
			activePlayers[i].playerMarker.Activate();
		}
	}

	public void HideUI()
	{
		GameController.hideUI = !GameController.hideUI;
		Image[] componentsInChildren = GameController.gameUI.GetComponentsInChildren<Image>();
		foreach (Image image in componentsInChildren)
		{
			if (!(image.gameObject.name == "DialogBox") && (!(image.transform.parent != null) || !(image.transform.parent.gameObject.name == "DialogBox")))
			{
				image.enabled = false;
			}
		}
		Text[] componentsInChildren2 = GameController.gameUI.GetComponentsInChildren<Text>();
		foreach (Text text in componentsInChildren2)
		{
			if (!(text.gameObject.name == "DialogBox") && (!(text.transform.parent != null) || !(text.transform.parent.gameObject.name == "DialogBox")))
			{
				text.enabled = false;
			}
		}
		PlayerStatusBar[] playerStatusBars = GameController.playerStatusBars;
		for (int i = 0; i < playerStatusBars.Length; i++)
		{
			Canvas component = playerStatusBars[i].GetComponent<Canvas>();
			component.enabled = !component.enabled;
		}
		Player[] activePlayers = GameController.activePlayers;
		foreach (Player obj in activePlayers)
		{
			obj.playerMarker.gameObject.SetActive(value: false);
			obj.lowerHUD.cooldownUI.stockSkill.mapBG.enabled = false;
			obj.lowerHUD.cooldownUI.stockSkill.mapBGOverlay.enabled = false;
			obj.lowerHUD.cooldownUI.stockSkill.mapButtonImage.enabled = false;
			obj.lowerHUD.cooldownUI.stockSkill.mapPrompt.enabled = false;
		}
		foreach (GameObject boss in GameController.bosses)
		{
			boss.GetComponent<Boss>().healthBar.gameObject.SetActive(value: false);
		}
	}

	public void SpawnSkillMerchant()
	{
	}

	public void SpawnAlly()
	{
	}

	public void UnlockEverything()
	{
		Player[] activePlayers = GameController.activePlayers;
		for (int i = 0; i < activePlayers.Length; i++)
		{
			foreach (Player.SkillState value in activePlayers[i].skillsDict.Values)
			{
				value.isUnlocked = true;
				value.signatureUnlocked = value.hasSignatureVariant;
			}
		}
		GameDataManager.gameData.PushSkillData();
		foreach (Outfit value2 in Outfit.OutfitDict.Values)
		{
			Outfit.UnlockOutfit(value2.outfitID, pushData: false);
		}
		GameDataManager.gameData.PushOutfitData();
		foreach (GameData.StoredItemData value3 in GameDataManager.gameData.ItemDataDict.Values)
		{
			value3.isUnlocked = true;
		}
	}

	public void PrintGameData()
	{
		GameDataManager.gameData.PrintData();
	}

	public void ClearSettings()
	{
		Debug.Log("Settings cleared.");
		GameDataManager.gameSettings.Reset();
		GameDataManager.SaveSettings();
	}

	public void ClearGameData()
	{
		Debug.Log("All Data cleared.");
		GameDataManager.ResetAllData();
	}

	public void ToggleCameraLock()
	{
		GameController.cameraController.disablePlayerTracking = !GameController.cameraController.disablePlayerTracking;
		GameController.cameraController.lockToSpawnPos = !GameController.cameraController.lockToSpawnPos;
		GameController.cameraController.spawnPos = GameController.cameraController.transform.position;
	}

	public void DevHub()
	{
		GameController.LoadLevel("DevHub");
	}

	public static void SpawnEnemy(string enemyName, Vector3 pos)
	{
		PoolManager.GetPoolItem<SpawnPortal>().Spawn(pos, SpawnPortal.enemyColor);
		Object.Instantiate(Enemy.EnemyPrefabObjects[enemyName], pos, Quaternion.identity);
	}

	public void SpawnWardrobe()
	{
		if (GameController.activePlayers.Length != 0)
		{
			Object.Instantiate(ChaosBundle.Get("Assets/Prefabs/Allies/WardrobeNpc.prefab"), GameController.activePlayers[0].transform.position, Quaternion.identity);
		}
	}
}
