Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Skapa en ny form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Subfolder Directory Manager"
$Form.Size = New-Object System.Drawing.Size(600, 520)
$Form.StartPosition = "CenterScreen"

# Skapa en TreeView för att visa mappar och undermappar
$TreeView = New-Object System.Windows.Forms.TreeView
$TreeView.Dock = "Top"
$TreeView.Height = 350
$TreeView.CheckBoxes = $true  # Tillåter att markera mappar
$TreeView.FullRowSelect = $true

# Skapa en TableLayoutPanel för knapparna
$ButtonPanel = New-Object System.Windows.Forms.TableLayoutPanel
$ButtonPanel.Dock = "Bottom"
$ButtonPanel.ColumnCount = 5
$ButtonPanel.RowCount = 2
$ButtonPanel.AutoSize = $true
$ButtonPanel.AutoSizeMode = "GrowAndShrink"
$ButtonPanel.Padding = New-Object System.Windows.Forms.Padding(10)
$ButtonPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
$ButtonPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))

# Skapa en TextBox för att ange undermappens namn med bakgrundstext
$TextBox = New-Object System.Windows.Forms.TextBox
$TextBox.Width = 300
$TextBox.Top = 360
$TextBox.Left = 50
$TextBox.ForeColor = [System.Drawing.Color]::Gray
$TextBox.Text = "Enter subfolder name..."  # Placeholder text
$Form.Controls.Add($TextBox)

# Event hantering för när användaren börjar skriva
$TextBox.Add_Enter({
    if ($TextBox.Text -eq "Enter subfolder name...") {
        $TextBox.Text = ""
        $TextBox.ForeColor = [System.Drawing.Color]::Black
    }
})

# Skapa knappar
$LoadButton = New-Object System.Windows.Forms.Button
$LoadButton.Text = "Load Folders"
$LoadButton.Width = 120
$LoadButton.Height = 30

$CreateButton = New-Object System.Windows.Forms.Button
$CreateButton.Text = "Create Subfolder"
$CreateButton.Width = 120
$CreateButton.Height = 30

$MarkButton = New-Object System.Windows.Forms.Button
$MarkButton.Text = "Mark All"
$MarkButton.Width = 120
$MarkButton.Height = 30

$UnmarkButton = New-Object System.Windows.Forms.Button
$UnmarkButton.Text = "Unmark All"
$UnmarkButton.Width = 150
$UnmarkButton.Height = 30

$DeleteButton = New-Object System.Windows.Forms.Button
$DeleteButton.Text = "Delete Marked Folders"
$DeleteButton.Width = 150
$DeleteButton.Height = 30

# Lägg till knapparna i TableLayoutPanel
$ButtonPanel.Controls.Add($TextBox, 1, 0)
$ButtonPanel.SetColumnSpan($TextBox, 2)
$ButtonPanel.Controls.Add($LoadButton, 0, 0)
$ButtonPanel.Controls.Add($CreateButton, 0, 1)
$ButtonPanel.SetColumnSpan($CreateButton, 1)
$ButtonPanel.Controls.Add($MarkButton, 0, 2)
$ButtonPanel.SetColumnSpan($MarkButton, 1)
$ButtonPanel.Controls.Add($UnmarkButton, 1, 2)
$ButtonPanel.Controls.Add($DeleteButton, 1, 1)

# Lägg till kontroller i huvudformuläret
$Form.Controls.Add($TreeView)
$Form.Controls.Add($ButtonPanel)

# Variabel för att lagra den valda mappen
$global:selectedFolder = ""

# Funktion för att lägga till mappar i TreeView
function Add-FoldersToTreeView {
    param (
        [string]$path,
        [System.Windows.Forms.TreeNode]$parentNode
    )

    $directories = Get-ChildItem -Path $path -Directory
    foreach ($directory in $directories) {
        $node = New-Object System.Windows.Forms.TreeNode($directory.Name)
        $node.Tag = $directory.FullName
        if ($parentNode) {
            $parentNode.Nodes.Add($node)
        } else {
            $TreeView.Nodes.Add($node)
        }

        # Recursively add subdirectories
        Add-FoldersToTreeView -path $directory.FullName -parentNode $node
    }
}

# Hantera knappen för att lägga till mappar
$LoadButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select a folder to display all subfolders."
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:selectedFolder = $folderBrowser.SelectedPath
        $TreeView.Nodes.Clear()
        Add-FoldersToTreeView -path $selectedFolder -parentNode $null
        $TreeView.ExpandAll()  # Expand all nodes by default
    }
})

# Hantera knappen för att skapa undermappar
$CreateButton.Add_Click({
    $foldername = $TextBox.Text.Trim()
    if ($foldername -eq "Enter subfolder name..." -or [string]::IsNullOrWhiteSpace($foldername)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a name for the subfolder.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $messages = @()
    $createdFolderPath = ""

    function Create-Subfolder {
        param (
            [System.Windows.Forms.TreeNode]$node,
            [string]$foldername
        )

        if ($node.Checked) {
            $folderPath = $node.Tag
            if (Test-Path $folderPath) {
                $newFolderPath = Join-Path $folderPath $foldername
                if (-not (Test-Path $newFolderPath)) {
                    New-Item -ItemType Directory -Path $newFolderPath -Force
                    $global:createdFolderPath = $newFolderPath
                    $messages += "Created folder: $newFolderPath"
                } else {
                    $messages += "Folder already exists: $newFolderPath"
                }
            } else {
                $messages += "Folder does not exist: $folderPath"
            }
        }

        foreach ($childNode in $node.Nodes) {
            Create-Subfolder -node $childNode -foldername $foldername
        }
    }

    foreach ($node in $TreeView.Nodes) {
        Create-Subfolder -node $node -foldername $foldername
    }

    # Uppdatera TreeView efter att mappen har skapats
    $TreeView.Nodes.Clear()
    Add-FoldersToTreeView -path $global:selectedFolder -parentNode $null
    $TreeView.ExpandAll()

    # Navigera automatiskt till den nya undermappen
    if ($global:createdFolderPath -ne "") {
        foreach ($rootNode in $TreeView.Nodes) {
            function Navigate-ToCreatedFolder {
                param (
                    [System.Windows.Forms.TreeNode]$node
                )

                if ($node.Tag -eq $global:createdFolderPath) {
                    $TreeView.SelectedNode = $node
                    $node.EnsureVisible()
                    $node.Expand()
                } else {
                    foreach ($childNode in $node.Nodes) {
                        Navigate-ToCreatedFolder -node $childNode
                    }
                }
            }

            Navigate-ToCreatedFolder -node $rootNode
        }
    }

    # Visa ett meddelande om att undermappen har skapats
    if ($messages.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show([string]::Join("rn", $messages), "Result", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

# Funktion för att markera alla noder med samma namn
function Mark-AllNodesWithSameName {
    param (
        [string]$nodeName
    )

    function Process-Node {
        param (
            [System.Windows.Forms.TreeNode]$node
        )

        # Kontrollera om noden är synlig (expanderad)
        if ($node.IsVisible -and $node.Text -eq $nodeName) {
            $node.Checked = $true
        }

        # Recursively check child nodes only if the current node is expanded
        if ($node.IsExpanded) {
            foreach ($childNode in $node.Nodes) {
                Process-Node -node $childNode
            }
        }
    }

    # Gå igenom alla rötter i TreeView
    foreach ($node in $TreeView.Nodes) {
        Process-Node -node $node
    }
}

# Hantera knappen för att markera alla mappar med samma namn
$MarkButton.Add_Click({
    $selectedNode = $TreeView.SelectedNode
    if ($selectedNode -and $selectedNode.Text) {
        $nodeName = $selectedNode.Text
        Mark-AllNodesWithSameName -nodeName $nodeName
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a node to match by name.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Hantera knappen för att avmarkera alla mappar
$UnmarkButton.Add_Click({
    function Unmark-AllNodes {
        param (
            [System.Windows.Forms.TreeNode]$node
        )

        $node.Checked = $false

        foreach ($childNode in $node.Nodes) {
            Unmark-AllNodes -node $childNode
        }
    }

    foreach ($node in $TreeView.Nodes) {
        Unmark-AllNodes -node $node
    }
})

# Hantera knappen för att radera markerade mappar
$DeleteButton.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete the selected folders?", "Confirm Deletion", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $messages = @()

        function Delete-MarkNodes {
            param (
                [System.Windows.Forms.TreeNode]$node
            )

            if ($node.Checked) {
                $folderPath = $node.Tag
                if (Test-Path $folderPath) {
                    Remove-Item -Path $folderPath -Recurse -Force
                    $messages += "Deleted folder: $folderPath"
                }
            }

            foreach ($childNode in $node.Nodes) {
                Delete-MarkNodes -node $childNode
            }
        }

        foreach ($node in $TreeView.Nodes) {
            Delete-MarkNodes -node $node
        }

        # Uppdatera TreeView efter att mappar har raderats
        $TreeView.Nodes.Clear()
        Add-FoldersToTreeView -path $global:selectedFolder -parentNode $null
        $TreeView.ExpandAll()

        # Navigera automatiskt tillbaka till den ursprungliga mappen
        foreach ($rootNode in $TreeView.Nodes) {
            if ($rootNode.Tag -eq $global:selectedFolder) {
                $TreeView.SelectedNode = $rootNode
                $rootNode.Expand()
                break
            }
        }

        # Visa resultatet av raderingen
        if ($messages.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show([string]::Join("rn", $messages), "Deletion Result", [System.Windows.Forms.MessageBox]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
})

# Hantera Resize-händelse för att justera TreeView storlek
$Form.Add_Resize({
    $TreeView.Width = $Form.ClientSize.Width
    $TreeView.Height = $Form.ClientSize.Height - $ButtonPanel.Height
})

# Visa formuläret
$Form.Topmost = $true
$Form.Add_Shown({ $Form.Activate() })
[void]$Form.ShowDialog()