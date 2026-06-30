using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

internal static class InstallerBootstrap
{
    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        bool quiet = HasSwitch(args, "--quiet");
        string installRoot = GetOption(args, "--install-dir");
        if (String.IsNullOrWhiteSpace(installRoot))
        {
            installRoot = PromptForInstallRoot();
        }
        if (String.IsNullOrWhiteSpace(installRoot))
        {
            return 1;
        }

        try
        {
            Directory.CreateDirectory(installRoot);
            ExtractPayload(installRoot);
            RunInstallScript(installRoot);
            if (!quiet)
            {
                MessageBox.Show("Installation complete. A desktop shortcut named iPhone Mirroring was created.",
                    "iPhone Mirroring Setup", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            return 0;
        }
        catch (Exception ex)
        {
            if (quiet)
            {
                Console.Error.WriteLine(ex.Message);
            }
            else
            {
                MessageBox.Show(ex.Message, "iPhone Mirroring Setup Failed",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            return 1;
        }
    }

    private static bool HasSwitch(string[] args, string name)
    {
        foreach (string arg in args)
        {
            if (String.Equals(arg, name, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        return false;
    }

    private static string GetOption(string[] args, string name)
    {
        for (int i = 0; i < args.Length; i++)
        {
            string arg = args[i];
            if (arg.StartsWith(name + "=", StringComparison.OrdinalIgnoreCase))
            {
                return arg.Substring(name.Length + 1).Trim('"');
            }
            if (String.Equals(arg, name, StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                return args[i + 1].Trim('"');
            }
        }
        return null;
    }

    private static string PromptForInstallRoot()
    {
        using (Form form = new Form())
        using (Label label = new Label())
        using (TextBox textBox = new TextBox())
        using (Button browseButton = new Button())
        using (Button okButton = new Button())
        using (Button cancelButton = new Button())
        {
            form.Text = "iPhone Mirroring Setup";
            form.StartPosition = FormStartPosition.CenterScreen;
            form.FormBorderStyle = FormBorderStyle.FixedDialog;
            form.MaximizeBox = false;
            form.MinimizeBox = false;
            form.ClientSize = new System.Drawing.Size(560, 135);

            label.Text = "Install to:";
            label.AutoSize = true;
            label.Left = 16;
            label.Top = 18;

            textBox.Left = 16;
            textBox.Top = 42;
            textBox.Width = 450;
            textBox.Text = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "iPhoneMirroring");

            browseButton.Text = "...";
            browseButton.Left = 478;
            browseButton.Top = 40;
            browseButton.Width = 55;
            browseButton.Click += delegate
            {
                using (FolderBrowserDialog dialog = new FolderBrowserDialog())
                {
                    dialog.Description = "Choose the iPhone Mirroring install folder";
                    dialog.ShowNewFolderButton = true;
                    if (Directory.Exists(textBox.Text))
                    {
                        dialog.SelectedPath = textBox.Text;
                    }
                    if (dialog.ShowDialog(form) == DialogResult.OK)
                    {
                        textBox.Text = dialog.SelectedPath;
                    }
                }
            };

            okButton.Text = "Install";
            okButton.Left = 330;
            okButton.Top = 92;
            okButton.Width = 90;
            okButton.DialogResult = DialogResult.OK;

            cancelButton.Text = "Cancel";
            cancelButton.Left = 442;
            cancelButton.Top = 92;
            cancelButton.Width = 90;
            cancelButton.DialogResult = DialogResult.Cancel;

            form.Controls.Add(label);
            form.Controls.Add(textBox);
            form.Controls.Add(browseButton);
            form.Controls.Add(okButton);
            form.Controls.Add(cancelButton);
            form.AcceptButton = okButton;
            form.CancelButton = cancelButton;

            return form.ShowDialog() == DialogResult.OK ? textBox.Text.Trim() : null;
        }
    }

    private static void ExtractPayload(string installRoot)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream stream = assembly.GetManifestResourceStream("payload.zip"))
        {
            if (stream == null)
            {
                throw new InvalidOperationException("Embedded installer payload was not found.");
            }

            using (ZipArchive archive = new ZipArchive(stream, ZipArchiveMode.Read))
            {
                string rootFullPath = Path.GetFullPath(installRoot);
                if (!rootFullPath.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal))
                {
                    rootFullPath += Path.DirectorySeparatorChar;
                }

                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string destinationPath = Path.GetFullPath(Path.Combine(installRoot, entry.FullName));
                    if (!destinationPath.StartsWith(rootFullPath, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException("The installer payload contains an invalid path.");
                    }

                    if (String.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(destinationPath);
                        continue;
                    }

                    Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                    entry.ExtractToFile(destinationPath, true);
                }
            }
        }
    }

    private static void RunInstallScript(string installRoot)
    {
        string scriptPath = Path.Combine(installRoot, "install.ps1");
        if (!File.Exists(scriptPath))
        {
            throw new FileNotFoundException("install.ps1 was not extracted.", scriptPath);
        }

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = "powershell.exe";
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"";
        psi.WorkingDirectory = installRoot;
        psi.UseShellExecute = true;

        using (Process process = Process.Start(psi))
        {
            process.WaitForExit();
            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException("install.ps1 exited with code " + process.ExitCode + ".");
            }
        }
    }
}
