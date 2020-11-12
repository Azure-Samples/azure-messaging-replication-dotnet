using System;
using McMaster.Extensions.CommandLineUtils;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Reflection;
using McMaster.Extensions.CommandLineUtils.Abstractions;
using McMaster.Extensions.CommandLineUtils.HelpText;


namespace ServiceBusCopyValidation
{
    using System.Globalization;
    using System.Runtime.CompilerServices;
    using System.Threading.Tasks;

    class Program
    {
        static void Main(string[] args)
        {
            // before we localize, make sure we have all the error
            // messages in en-us
            CultureInfo.CurrentUICulture =
                CultureInfo.DefaultThreadCurrentUICulture =
                    CultureInfo.GetCultureInfoByIetfLanguageTag("en-us");

            try
            { 
                CommandLineSettings.Run(args, (c) => Run(c, args)).GetAwaiter().GetResult();
            }
            catch(CommandParsingException exception)
            {
                Console.WriteLine(exception.Message);
            }
        }

        static async Task<int> Run(CommandLineSettings settings, string[] args)
        {
            try
            {
                var plt = new ServiceBusCopyTest(settings.TargetNamespaceConnectionString,
                    settings.SourceNamespaceConnectionString, settings.TargetQueue, settings.SourceQueue);
                await plt.RunTest();
            }
            catch (Exception e)
            {
                Console.WriteLine(e.ToString());
                return 1;
            }
            return 0;
        }
    }


    public class CommandLineSettings
    {
        [Option(CommandOptionType.SingleValue, ShortName = "t", Description = "Target namespace connection string")]
        public string TargetNamespaceConnectionString { get; set; }
        [Option(CommandOptionType.SingleValue, ShortName = "s", Description = "Source namespace connection string")]
        public string SourceNamespaceConnectionString { get; set; }
        [Option(CommandOptionType.SingleValue, ShortName = "qt", Description = "Target Queue")]
        public string TargetQueue { get; set; }
        [Option(CommandOptionType.SingleValue, ShortName = "qs", Description = "Source Queue")]
        public string SourceQueue { get; set; }


        public static async Task<int> Run(string[] args, Func<CommandLineSettings, Task<int>> callback)
        {
            CommandLineApplication<CommandLineSettings> app = new CommandLineApplication<CommandLineSettings>
            {
                ModelFactory = () => new CommandLineSettings()
            };
            app.Conventions.UseDefaultConventions().SetAppNameFromEntryAssembly();
            app.Parse(args);
            return await callback(app.Model);
        }
    }
}
